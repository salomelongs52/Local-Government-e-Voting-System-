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

(define-data-var proposal-count uint u0)
(define-data-var admin-address principal contract-owner)
(define-data-var minimum-vote-threshold uint u10)

(define-map Voters
    principal
    {
        registered: bool,
        registration-block: uint,
        last-vote: (optional uint),
    }
)

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

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (var-set admin-address new-owner)
        (ok true)
    )
)

(define-constant err-invalid-delegation (err u109))
(define-constant err-delegation-not-found (err u110))
(define-constant err-self-delegation (err u111))

(define-map VoterDelegations
    principal
    {
        delegate: principal,
        delegation-block: uint,
        active: bool,
    }
)

(define-map DelegateVotingPower
    principal
    uint
)

(define-read-only (get-delegation (voter principal))
    (map-get? VoterDelegations voter)
)

(define-read-only (get-voting-power (delegate principal))
    (default-to u1 (map-get? DelegateVotingPower delegate))
)

(define-public (delegate-vote (delegate principal))
    (let (
            (voter (get-voter tx-sender))
            (delegate-info (get-voter delegate))
            (current-power (get-voting-power delegate))
        )
        (asserts! (get registered voter) err-not-registered)
        (asserts! (get registered delegate-info) err-not-registered)
        (asserts! (not (is-eq tx-sender delegate)) err-self-delegation)
        (asserts! (is-none (map-get? VoterDelegations tx-sender))
            err-invalid-delegation
        )
        (map-set VoterDelegations tx-sender {
            delegate: delegate,
            delegation-block: stacks-block-height,
            active: true,
        })
        (map-set DelegateVotingPower delegate (+ current-power u1))
        (ok true)
    )
)

(define-public (revoke-delegation)
    (let (
            (delegation (unwrap! (map-get? VoterDelegations tx-sender)
                err-delegation-not-found
            ))
            (delegate (get delegate delegation))
            (current-power (get-voting-power delegate))
        )
        (map-delete VoterDelegations tx-sender)
        (map-set DelegateVotingPower delegate (- current-power u1))
        (ok true)
    )
)

(define-public (vote-as-delegate
        (proposal-id uint)
        (vote-value (string-ascii 10))
    )
    (let (
            (voter (get-voter tx-sender))
            (proposal (unwrap! (map-get? Proposals proposal-id) err-proposal-not-found))
            (voting-power (get-voting-power tx-sender))
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
                    (+ (get yes-votes proposal) voting-power)
                    (get yes-votes proposal)
                ),
                no-votes: (if (is-eq vote-value "no")
                    (+ (get no-votes proposal) voting-power)
                    (get no-votes proposal)
                ),
                abstain-votes: (if (is-eq vote-value "abstain")
                    (+ (get abstain-votes proposal) voting-power)
                    (get abstain-votes proposal)
                ),
            })
        )
        (ok true)
    )
)
(define-constant err-invalid-category (err u112))
(define-constant err-category-exists (err u113))
(define-constant err-insufficient-votes (err u114))

(define-map ProposalCategories
    (string-ascii 30)
    {
        name: (string-ascii 30),
        description: (string-ascii 200),
        active: bool,
        proposal-count: uint,
    }
)

(define-map ProposalCategoryMapping
    uint
    (string-ascii 30)
)

(define-map CategoryProposals
    {
        category: (string-ascii 30),
        proposal-id: uint,
    }
    bool
)

(define-read-only (get-category (category-id (string-ascii 30)))
    (map-get? ProposalCategories category-id)
)

(define-read-only (get-proposal-category (proposal-id uint))
    (map-get? ProposalCategoryMapping proposal-id)
)

(define-read-only (is-proposal-in-category
        (category-id (string-ascii 30))
        (proposal-id uint)
    )
    (default-to false
        (map-get? CategoryProposals {
            category: category-id,
            proposal-id: proposal-id,
        })
    )
)

(define-public (create-category
        (category-id (string-ascii 30))
        (name (string-ascii 30))
        (description (string-ascii 200))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (is-none (map-get? ProposalCategories category-id))
            err-category-exists
        )
        (map-set ProposalCategories category-id {
            name: name,
            description: description,
            active: true,
            proposal-count: u0,
        })
        (ok true)
    )
)

(define-public (create-categorized-proposal
        (title (string-ascii 100))
        (description (string-ascii 500))
        (voting-period uint)
        (category-id (string-ascii 30))
    )
    (let (
            (voter (get-voter tx-sender))
            (proposal-id (var-get proposal-count))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height voting-period))
            (category (unwrap! (map-get? ProposalCategories category-id)
                err-invalid-category
            ))
        )
        (asserts! (get registered voter) err-not-registered)
        (asserts! (> voting-period u0) err-invalid-period)
        (asserts! (get active category) err-invalid-category)
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
        (map-set ProposalCategoryMapping proposal-id category-id)
        (map-set CategoryProposals {
            category: category-id,
            proposal-id: proposal-id,
        }
            true
        )
        (map-set ProposalCategories category-id
            (merge category { proposal-count: (+ (get proposal-count category) u1) })
        )
        (var-set proposal-count (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (deactivate-category (category-id (string-ascii 30)))
    (let ((category (unwrap! (map-get? ProposalCategories category-id) err-invalid-category)))
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (map-set ProposalCategories category-id
            (merge category { active: false })
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
