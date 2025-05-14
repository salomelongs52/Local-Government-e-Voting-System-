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
    (let ((proposal (unwrap! (map-get? Proposals proposal-id) err-proposal-not-found)))
        (asserts!
            (or
                (>= stacks-block-height (get end-block proposal))
                (is-eq tx-sender contract-owner)
            )
            err-not-authorized
        )
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
