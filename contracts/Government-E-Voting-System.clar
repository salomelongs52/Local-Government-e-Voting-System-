;;  Government E-Voting System with Campaign Finance Transparency
;;  A comprehensive smart contract for local government elections and campaign oversight

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-proposal-exists (err u103))
(define-constant err-proposal-not-found (err u104))
(define-constant err-voting-closed (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-invalid-vote (err u107))
(define-constant err-invalid-period (err u108))
(define-constant err-insufficient-votes (err u109))

;; Core voting system data variables
(define-data-var proposal-count uint u0)
(define-data-var admin-address principal contract-owner)
(define-data-var minimum-vote-threshold uint u10)

;; Voter management
(define-map Voters
    principal
    {
        registered: bool,
        registration-block: uint,
        last-vote: (optional uint),
    }
)

;; Proposal management
(define-map Proposals
    uint
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        yes-votes: uint,
        no-votes: uint,
        abstain-votes: uint,
        start-block: uint,
        end-block: uint,
        is-active: bool,
        result-finalized: bool,
    }
)

;; Vote tracking
(define-map VoteRegistry
    {
        proposal-id: uint,
        voter: principal,
    }
    {
        vote-value: (string-ascii 10),
        stacks-block-height: uint,
    }
)

;; Election districts
(define-map ElectionDistricts
    (string-ascii 50)
    {
        name: (string-ascii 50),
        active: bool,
        voter-count: uint,
    }
)

(define-map VoterDistricts
    principal
    (string-ascii 50)
)

;; Read-only functions for core voting system
(define-read-only (get-proposal (proposal-id uint))
    (match (map-get? Proposals proposal-id)
        proposal (ok proposal)
        err-proposal-not-found
    )
)

(define-read-only (get-voter (address principal))
    (default-to {
        registered: false,
        registration-block: u0,
        last-vote: none,
    }
        (map-get? Voters address)
    )
)

(define-read-only (get-vote
        (proposal-id uint)
        (voter principal)
    )
    (map-get? VoteRegistry {
        proposal-id: proposal-id,
        voter: voter,
    })
)

(define-read-only (get-district (district-id (string-ascii 50)))
    (map-get? ElectionDistricts district-id)
)

(define-read-only (get-voter-district (voter principal))
    (map-get? VoterDistricts voter)
)

(define-read-only (get-proposal-count)
    (var-get proposal-count)
)

(define-read-only (get-minimum-vote-threshold)
    (var-get minimum-vote-threshold)
)

(define-read-only (get-total-votes (proposal-id uint))
    (match (map-get? Proposals proposal-id)
        proposal (ok (+ (+ (get yes-votes proposal) (get no-votes proposal))
            (get abstain-votes proposal)
        ))
        err-proposal-not-found
    )
)

;; Core voting system public functions
(define-public (register-voter (district-id (string-ascii 50)))
    (let (
            (voter (get-voter tx-sender))
            (district (default-to {
                name: district-id,
                active: false,
                voter-count: u0,
            }
                (map-get? ElectionDistricts district-id)
            ))
        )
        (asserts! (not (get registered voter)) err-already-registered)
        (asserts! (is-some (map-get? ElectionDistricts district-id))
            err-not-authorized
        )
        (map-set Voters tx-sender {
            registered: true,
            registration-block: stacks-block-height,
            last-vote: none,
        })
        (map-set ElectionDistricts district-id
            (merge district { voter-count: (+ (get voter-count district) u1) })
        )
        (map-set VoterDistricts tx-sender district-id)
        (ok true)
    )
)

(define-public (create-proposal
        (title (string-ascii 100))
        (description (string-ascii 500))
        (voting-period uint)
    )
    (let (
            (voter (get-voter tx-sender))
            (proposal-id (var-get proposal-count))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height voting-period))
        )
        (asserts! (get registered voter) err-not-registered)
        (asserts! (> voting-period u0) err-invalid-period)
        (map-set Proposals proposal-id {
            title: title,
            description: description,
            creator: tx-sender,
            yes-votes: u0,
            no-votes: u0,
            abstain-votes: u0,
            start-block: start-block,
            end-block: end-block,
            is-active: true,
            result-finalized: false,
        })
        (var-set proposal-count (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote
        (proposal-id uint)
        (vote-value (string-ascii 10))
    )
    (let (
            (voter (get-voter tx-sender))
            (proposal (unwrap! (map-get? Proposals proposal-id) err-proposal-not-found))
        )
        (asserts! (get registered voter) err-not-registered)
        (asserts! (get is-active proposal) err-voting-closed)
        (asserts! (<= stacks-block-height (get end-block proposal))
            err-voting-closed
        )
        (asserts!
            (or
                (is-eq vote-value "yes")
                (is-eq vote-value "no")
                (is-eq vote-value "abstain")
            )
            err-invalid-vote
        )
        (asserts!
            (is-none (map-get? VoteRegistry {
                proposal-id: proposal-id,
                voter: tx-sender,
            }))
            err-already-voted
        )
        (map-set VoteRegistry {
            proposal-id: proposal-id,
            voter: tx-sender,
        } {
            vote-value: vote-value,
            stacks-block-height: stacks-block-height,
        })
        (map-set Proposals proposal-id
            (merge proposal {
                yes-votes: (if (is-eq vote-value "yes")
                    (+ (get yes-votes proposal) u1)
                    (get yes-votes proposal)
                ),
                no-votes: (if (is-eq vote-value "no")
                    (+ (get no-votes proposal) u1)
                    (get no-votes proposal)
                ),
                abstain-votes: (if (is-eq vote-value "abstain")
                    (+ (get abstain-votes proposal) u1)
                    (get abstain-votes proposal)
                ),
            })
        )
        (map-set Voters tx-sender (merge voter { last-vote: (some proposal-id) }))
        (ok true)
    )
)

(define-public (close-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? Proposals proposal-id) err-proposal-not-found))
            (total-votes (+ (+ (get yes-votes proposal) (get no-votes proposal))
                (get abstain-votes proposal)
            ))
            (min-threshold (var-get minimum-vote-threshold))
        )
        (asserts!
            (or
                (>= stacks-block-height (get end-block proposal))
                (is-eq tx-sender contract-owner)
            )
            err-not-authorized
        )
        (asserts! (>= total-votes min-threshold) err-insufficient-votes)
        (map-set Proposals proposal-id
            (merge proposal {
                is-active: false,
                result-finalized: true,
            })
        )
        (ok true)
    )
)

(define-public (create-district
        (district-id (string-ascii 50))
        (name (string-ascii 50))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set ElectionDistricts district-id {
            name: name,
            active: true,
            voter-count: u0,
        })
        (ok true)
    )
)

(define-public (deactivate-district (district-id (string-ascii 50)))
    (let ((district (default-to {
            name: "",
            active: false,
            voter-count: u0,
        }
            (map-get? ElectionDistricts district-id)
        )))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set ElectionDistricts district-id (merge district { active: false }))
        (ok true)
    )
)

;; Campaign Finance Transparency Feature
;; Independent module for tracking campaign contributions and expenditures

;; Campaign Finance Error constants
(define-constant err-campaign-not-found (err u110))
(define-constant err-campaign-exists (err u111))
(define-constant err-invalid-amount (err u112))
(define-constant err-contribution-limit-exceeded (err u113))
(define-constant err-campaign-inactive (err u114))
(define-constant err-expenditure-exceeds-funds (err u115))
(define-constant err-invalid-contributor (err u116))
(define-constant err-reporting-period-closed (err u117))

;; Campaign Finance Data Variables
(define-data-var campaign-count uint u0)
(define-data-var max-individual-contribution uint u1000000) ;; 1 million microSTX
(define-data-var reporting-period-length uint u144) ;; ~1 day in blocks
(define-data-var contribution-count uint u0)
(define-data-var expenditure-count uint u0)

;; Campaign registration and tracking
(define-map Campaigns
    uint
    {
        candidate: principal,
        campaign-name: (string-ascii 100),
        registration-block: uint,
        total-contributions: uint,
        total-expenditures: uint,
        active: bool,
        reporting-deadline: uint,
    }
)

;; Individual contribution tracking
(define-map Contributions
    uint
    {
        campaign-id: uint,
        contributor: principal,
        amount: uint,
        contribution-block: uint,
        verified: bool,
        contribution-type: (string-ascii 20),
    }
)

;; Expenditure tracking
(define-map Expenditures
    uint
    {
        campaign-id: uint,
        amount: uint,
        description: (string-ascii 200),
        recipient: (string-ascii 100),
        expenditure-block: uint,
        category: (string-ascii 50),
        approved: bool,
    }
)

;; Contributor limits tracking
(define-map ContributorTotals
    {
        campaign-id: uint,
        contributor: principal,
    }
    uint
)

;; Read-only functions for campaign finance
(define-read-only (get-campaign (campaign-id uint))
    (map-get? Campaigns campaign-id)
)

(define-read-only (get-contribution (contribution-id uint))
    (map-get? Contributions contribution-id)
)

(define-read-only (get-expenditure (expenditure-id uint))
    (map-get? Expenditures expenditure-id)
)

(define-read-only (get-contributor-total
        (campaign-id uint)
        (contributor principal)
    )
    (default-to u0
        (map-get? ContributorTotals {
            campaign-id: campaign-id,
            contributor: contributor,
        })
    )
)

(define-read-only (get-campaign-count)
    (var-get campaign-count)
)

(define-read-only (get-contribution-count)
    (var-get contribution-count)
)

(define-read-only (get-expenditure-count)
    (var-get expenditure-count)
)

(define-read-only (get-max-individual-contribution)
    (var-get max-individual-contribution)
)

(define-read-only (get-campaign-balance (campaign-id uint))
    (match (map-get? Campaigns campaign-id)
        campaign (ok (- (get total-contributions campaign) (get total-expenditures campaign)))
        err-campaign-not-found
    )
)

;; Public functions for campaign finance management
(define-public (register-campaign
        (candidate principal)
        (campaign-name (string-ascii 100))
    )
    (let (
            (campaign-id (var-get campaign-count))
            (current-block stacks-block-height)
            (reporting-deadline (+ current-block (var-get reporting-period-length)))
        )
        (asserts! (is-none (map-get? Campaigns campaign-id)) err-campaign-exists)
        (map-set Campaigns campaign-id {
            candidate: candidate,
            campaign-name: campaign-name,
            registration-block: current-block,
            total-contributions: u0,
            total-expenditures: u0,
            active: true,
            reporting-deadline: reporting-deadline,
        })
        (var-set campaign-count (+ campaign-id u1))
        (ok campaign-id)
    )
)

(define-public (make-contribution
        (campaign-id uint)
        (amount uint)
        (contribution-type (string-ascii 20))
    )
    (let (
            (campaign (unwrap! (map-get? Campaigns campaign-id) err-campaign-not-found))
            (contribution-id (var-get contribution-count))
            (current-contributor-total (get-contributor-total campaign-id tx-sender))
            (new-contributor-total (+ current-contributor-total amount))
            (max-contribution (var-get max-individual-contribution))
        )
        (asserts! (get active campaign) err-campaign-inactive)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (<= new-contributor-total max-contribution)
            err-contribution-limit-exceeded
        )
        (asserts! (<= stacks-block-height (get reporting-deadline campaign))
            err-reporting-period-closed
        )

        (map-set Contributions contribution-id {
            campaign-id: campaign-id,
            contributor: tx-sender,
            amount: amount,
            contribution-block: stacks-block-height,
            verified: false,
            contribution-type: contribution-type,
        })

        (map-set ContributorTotals {
            campaign-id: campaign-id,
            contributor: tx-sender,
        }
            new-contributor-total
        )

        (map-set Campaigns campaign-id
            (merge campaign { total-contributions: (+ (get total-contributions campaign) amount) })
        )

        (var-set contribution-count (+ contribution-id u1))
        (ok contribution-id)
    )
)

(define-public (record-expenditure
        (campaign-id uint)
        (amount uint)
        (description (string-ascii 200))
        (recipient (string-ascii 100))
        (category (string-ascii 50))
    )
    (let (
            (campaign (unwrap! (map-get? Campaigns campaign-id) err-campaign-not-found))
            (expenditure-id (var-get expenditure-count))
            (current-balance (- (get total-contributions campaign)
                (get total-expenditures campaign)
            ))
        )
        (asserts! (is-eq tx-sender (get candidate campaign)) err-not-authorized)
        (asserts! (get active campaign) err-campaign-inactive)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (<= amount current-balance) err-expenditure-exceeds-funds)

        (map-set Expenditures expenditure-id {
            campaign-id: campaign-id,
            amount: amount,
            description: description,
            recipient: recipient,
            expenditure-block: stacks-block-height,
            category: category,
            approved: false,
        })

        (map-set Campaigns campaign-id
            (merge campaign { total-expenditures: (+ (get total-expenditures campaign) amount) })
        )

        (var-set expenditure-count (+ expenditure-id u1))
        (ok expenditure-id)
    )
)

(define-public (verify-contribution (contribution-id uint))
    (let ((contribution (unwrap! (map-get? Contributions contribution-id) err-campaign-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set Contributions contribution-id
            (merge contribution { verified: true })
        )
        (ok true)
    )
)

(define-public (approve-expenditure (expenditure-id uint))
    (let ((expenditure (unwrap! (map-get? Expenditures expenditure-id) err-campaign-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set Expenditures expenditure-id
            (merge expenditure { approved: true })
        )
        (ok true)
    )
)

(define-public (deactivate-campaign (campaign-id uint))
    (let ((campaign (unwrap! (map-get? Campaigns campaign-id) err-campaign-not-found)))
        (asserts!
            (or
                (is-eq tx-sender contract-owner)
                (is-eq tx-sender (get candidate campaign))
            )
            err-not-authorized
        )
        (map-set Campaigns campaign-id (merge campaign { active: false }))
        (ok true)
    )
)

(define-public (set-contribution-limit (new-limit uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> new-limit u0) err-invalid-amount)
        (var-set max-individual-contribution new-limit)
        (ok true)
    )
)

(define-public (extend-reporting-deadline
        (campaign-id uint)
        (additional-blocks uint)
    )
    (let (
            (campaign (unwrap! (map-get? Campaigns campaign-id) err-campaign-not-found))
            (current-deadline (get reporting-deadline campaign))
            (new-deadline (+ current-deadline additional-blocks))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (> additional-blocks u0) err-invalid-amount)
        (map-set Campaigns campaign-id
            (merge campaign { reporting-deadline: new-deadline })
        )
        (ok true)
    )
)

(define-public (set-minimum-vote-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (var-set minimum-vote-threshold new-threshold)
        (ok true)
    )
)

(define-constant err-auditor-not-found (err u118))
(define-constant err-auditor-exists (err u119))
(define-constant err-auditor-inactive (err u120))
(define-constant err-report-not-found (err u121))
(define-constant err-report-exists (err u122))
(define-constant err-invalid-severity (err u123))
(define-constant err-invalid-target (err u124))

(define-data-var auditor-count uint u0)
(define-data-var audit-report-count uint u0)

(define-map Auditors
    principal
    {
        auditor-name: (string-ascii 100),
        registration-block: uint,
        active: bool,
        completed-audits: uint,
    }
)

(define-map AuditReports
    uint
    {
        auditor: principal,
        target-type: (string-ascii 20),
        target-id: uint,
        report-hash: (string-ascii 64),
        severity: (string-ascii 20),
        submission-block: uint,
        approved: bool,
        findings-summary: (string-ascii 500),
    }
)

(define-read-only (get-auditor (auditor principal))
    (map-get? Auditors auditor)
)

(define-read-only (get-audit-report (report-id uint))
    (map-get? AuditReports report-id)
)

(define-read-only (get-auditor-count)
    (var-get auditor-count)
)

(define-read-only (get-audit-report-count)
    (var-get audit-report-count)
)

(define-public (register-auditor
        (auditor-principal principal)
        (auditor-name (string-ascii 100))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-none (map-get? Auditors auditor-principal))
            err-auditor-exists
        )
        (map-set Auditors auditor-principal {
            auditor-name: auditor-name,
            registration-block: stacks-block-height,
            active: true,
            completed-audits: u0,
        })
        (var-set auditor-count (+ (var-get auditor-count) u1))
        (ok true)
    )
)

(define-public (submit-audit-report
        (target-type (string-ascii 20))
        (target-id uint)
        (report-hash (string-ascii 64))
        (severity (string-ascii 20))
        (findings-summary (string-ascii 500))
    )
    (let (
            (auditor (unwrap! (map-get? Auditors tx-sender) err-auditor-not-found))
            (report-id (var-get audit-report-count))
        )
        (asserts! (get active auditor) err-auditor-inactive)
        (asserts!
            (or
                (is-eq target-type "proposal")
                (is-eq target-type "campaign")
            )
            err-invalid-target
        )
        (asserts!
            (or
                (is-eq severity "critical")
                (is-eq severity "high")
                (is-eq severity "medium")
                (is-eq severity "low")
                (is-eq severity "informational")
            )
            err-invalid-severity
        )
        (map-set AuditReports report-id {
            auditor: tx-sender,
            target-type: target-type,
            target-id: target-id,
            report-hash: report-hash,
            severity: severity,
            submission-block: stacks-block-height,
            approved: false,
            findings-summary: findings-summary,
        })
        (map-set Auditors tx-sender
            (merge auditor { completed-audits: (+ (get completed-audits auditor) u1) })
        )
        (var-set audit-report-count (+ report-id u1))
        (ok report-id)
    )
)

(define-public (approve-audit-report (report-id uint))
    (let ((report (unwrap! (map-get? AuditReports report-id) err-report-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set AuditReports report-id (merge report { approved: true }))
        (ok true)
    )
)

(define-public (deactivate-auditor (auditor-principal principal))
    (let ((auditor (unwrap! (map-get? Auditors auditor-principal) err-auditor-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set Auditors auditor-principal (merge auditor { active: false }))
        (ok true)
    )
)
