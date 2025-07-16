(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_LOAN_NOT_PENDING (err u104))
(define-constant ERR_ALREADY_COSIGNED (err u105))
(define-constant ERR_NOT_COSIGNER (err u106))
(define-constant ERR_LOAN_NOT_ACTIVE (err u107))
(define-constant ERR_INSUFFICIENT_FUNDS (err u108))
(define-constant ERR_PAYMENT_TOO_EARLY (err u109))
(define-constant ERR_ALREADY_DEFAULTED (err u110))
(define-constant ERR_INVALID_DURATION (err u111))
(define-constant ERR_INVALID_INTEREST (err u112))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u113))
(define-constant ERR_COLLATERAL_LOCKED (err u114))
(define-constant ERR_LIQUIDATION_THRESHOLD_NOT_MET (err u115))

(define-data-var loan-counter uint u0)

(define-map loans uint {
    borrower: principal,
    cosigner: (optional principal),
    amount: uint,
    interest-rate: uint,
    duration-blocks: uint,
    created-at: uint,
    funded-at: (optional uint),
    repaid-amount: uint,
    status: (string-ascii 20),
    last-payment: (optional uint),
    collateral-amount: uint,
    collateral-ratio: uint
})

(define-map loan-payments uint {
    total-paid: uint,
    payments-made: uint,
    next-payment-due: uint
})

(define-map cosigner-requests {borrower: principal, cosigner: principal} {
    loan-id: uint,
    approved: bool,
    created-at: uint
})

(define-map user-stats principal {
    loans-created: uint,
    loans-cosigned: uint,
    total-borrowed: uint,
    total-cosigned: uint,
    defaults: uint
})

(define-map loan-collateral uint {
    deposited-amount: uint,
    liquidation-threshold: uint,
    is-locked: bool
})

(define-read-only (get-loan (loan-id uint))
    (map-get? loans loan-id))

(define-read-only (get-loan-payment-info (loan-id uint))
    (map-get? loan-payments loan-id))

(define-read-only (get-cosigner-request (borrower principal) (cosigner principal))
    (map-get? cosigner-requests {borrower: borrower, cosigner: cosigner}))

(define-read-only (get-user-stats (user principal))
    (default-to {loans-created: u0, loans-cosigned: u0, total-borrowed: u0, total-cosigned: u0, defaults: u0}
                (map-get? user-stats user)))

(define-read-only (get-loan-collateral (loan-id uint))
    (map-get? loan-collateral loan-id))

(define-read-only (calculate-collateral-ratio (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (match (map-get? loan-collateral loan-id)
            collateral-data
            (if (> (get amount loan-data) u0)
                (ok (/ (* (get deposited-amount collateral-data) u100) (get amount loan-data)))
                (ok u0))
            (ok u0))
        ERR_LOAN_NOT_FOUND))

(define-read-only (calculate-monthly-payment (amount uint) (interest-rate uint) (duration-blocks uint))
    (let ((monthly-interest (/ interest-rate u12))
          (total-amount (+ amount (/ (* amount interest-rate) u100))))
        (/ total-amount (/ duration-blocks u1008))))

(define-read-only (get-loan-status (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data (ok (get status loan-data))
        ERR_LOAN_NOT_FOUND))

(define-read-only (is-loan-overdue (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data 
        (match (get funded-at loan-data)
            funded-block
            (let ((payment-info (default-to {total-paid: u0, payments-made: u0, next-payment-due: u0}
                                           (map-get? loan-payments loan-id))))
                (> stacks-block-height (get next-payment-due payment-info)))
            false)
        false))

(define-private (update-user-stats (user principal) (field (string-ascii 20)) (amount uint))
    (let ((current-stats (get-user-stats user)))
        (map-set user-stats user
            (if (is-eq field "loans-created")
                (merge current-stats {loans-created: (+ (get loans-created current-stats) u1),
                                    total-borrowed: (+ (get total-borrowed current-stats) amount)})
                (if (is-eq field "loans-cosigned")
                    (merge current-stats {loans-cosigned: (+ (get loans-cosigned current-stats) u1),
                                        total-cosigned: (+ (get total-cosigned current-stats) amount)})
                    (if (is-eq field "defaults")
                        (merge current-stats {defaults: (+ (get defaults current-stats) u1)})
                        current-stats))))))

(define-public (create-loan (amount uint) (interest-rate uint) (duration-blocks uint))
    (let ((loan-id (+ (var-get loan-counter) u1)))
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= interest-rate u50) ERR_INVALID_INTEREST)
        (asserts! (and (>= duration-blocks u1008) (<= duration-blocks u52560)) ERR_INVALID_DURATION)
        (map-set loans loan-id {
            borrower: tx-sender,
            cosigner: none,
            amount: amount,
            interest-rate: interest-rate,
            duration-blocks: duration-blocks,
            created-at: stacks-block-height,
            funded-at: none,
            repaid-amount: u0,
            status: "pending",
            last-payment: none,
            collateral-amount: u0,
            collateral-ratio: u0
        })
        (update-user-stats tx-sender "loans-created" amount)
        (var-set loan-counter loan-id)
        (ok loan-id)))

(define-public (request-cosigner (loan-id uint) (cosigner principal))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_PENDING)
            (asserts! (is-none (map-get? cosigner-requests {borrower: tx-sender, cosigner: cosigner})) ERR_ALREADY_COSIGNED)
            (map-set cosigner-requests {borrower: tx-sender, cosigner: cosigner} {
                loan-id: loan-id,
                approved: false,
                created-at: stacks-block-height
            })
            (ok true))
        ERR_LOAN_NOT_FOUND))

(define-public (approve-cosigning (borrower principal))
    (match (map-get? cosigner-requests {borrower: borrower, cosigner: tx-sender})
        request-data
        (let ((loan-id (get loan-id request-data)))
            (match (map-get? loans loan-id)
                loan-data
                (begin
                    (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_PENDING)
                    (map-set cosigner-requests {borrower: borrower, cosigner: tx-sender}
                        (merge request-data {approved: true}))
                    (map-set loans loan-id
                        (merge loan-data {cosigner: (some tx-sender), status: "approved"}))
                    (update-user-stats tx-sender "loans-cosigned" (get amount loan-data))
                    (ok true))
                ERR_LOAN_NOT_FOUND))
        ERR_UNAUTHORIZED))

(define-public (fund-loan (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get status loan-data) "approved") ERR_LOAN_NOT_ACTIVE)
            (asserts! (is-some (get cosigner loan-data)) ERR_NOT_COSIGNER)
            (try! (stx-transfer? (get amount loan-data) tx-sender (get borrower loan-data)))
            (map-set loans loan-id
                (merge loan-data {
                    status: "active",
                    funded-at: (some stacks-block-height)
                }))
            (let ((monthly-payment (calculate-monthly-payment 
                                   (get amount loan-data) 
                                   (get interest-rate loan-data) 
                                   (get duration-blocks loan-data))))
                (map-set loan-payments loan-id {
                    total-paid: u0,
                    payments-made: u0,
                    next-payment-due: (+ stacks-block-height u1008)
                }))
            (ok true))
        ERR_LOAN_NOT_FOUND))

(define-public (make-payment (loan-id uint) (payment-amount uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
            (asserts! (> payment-amount u0) ERR_INVALID_AMOUNT)
            (let ((payment-info (default-to {total-paid: u0, payments-made: u0, next-payment-due: u0}
                                           (map-get? loan-payments loan-id)))
                  (new-total-paid (+ (get repaid-amount loan-data) payment-amount))
                  (total-amount-due (+ (get amount loan-data) 
                                     (/ (* (get amount loan-data) (get interest-rate loan-data)) u100))))
                (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
                (map-set loans loan-id
                    (merge loan-data {
                        repaid-amount: new-total-paid,
                        status: (if (>= new-total-paid total-amount-due) "completed" "active"),
                        last-payment: (some stacks-block-height)
                    }))
                (map-set loan-payments loan-id {
                    total-paid: new-total-paid,
                    payments-made: (+ (get payments-made payment-info) u1),
                    next-payment-due: (+ stacks-block-height u1008)
                })
                (ok true)))
        ERR_LOAN_NOT_FOUND))

(define-public (declare-default (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (or (is-eq tx-sender (get borrower loan-data))
                         (is-eq (some tx-sender) (get cosigner loan-data))) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
            (asserts! (is-loan-overdue loan-id) ERR_PAYMENT_TOO_EARLY)
            (map-set loans loan-id
                (merge loan-data {status: "defaulted"}))
            (update-user-stats (get borrower loan-data) "defaults" u0)
            (match (get cosigner loan-data)
                cosigner-principal (update-user-stats cosigner-principal "defaults" u0)
                true)
            (ok true))
        ERR_LOAN_NOT_FOUND))

(define-public (deposit-collateral (loan-id uint) (collateral-amount uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (or (is-eq (get status loan-data) "pending") (is-eq (get status loan-data) "active")) ERR_LOAN_NOT_ACTIVE)
            (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
            (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
            (let ((current-collateral (default-to {deposited-amount: u0, liquidation-threshold: u150, is-locked: false}
                                                 (map-get? loan-collateral loan-id)))
                  (new-total-collateral (+ (get deposited-amount current-collateral) collateral-amount))
                  (new-ratio (/ (* new-total-collateral u100) (get amount loan-data))))
                (map-set loan-collateral loan-id
                    (merge current-collateral {deposited-amount: new-total-collateral}))
                (map-set loans loan-id
                    (merge loan-data {collateral-amount: new-total-collateral, collateral-ratio: new-ratio}))
                (ok true)))
        ERR_LOAN_NOT_FOUND))

(define-public (withdraw-collateral (loan-id uint) (withdrawal-amount uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (or (is-eq (get status loan-data) "completed") (is-eq (get status loan-data) "pending")) ERR_COLLATERAL_LOCKED)
            (let ((collateral-info (default-to {deposited-amount: u0, liquidation-threshold: u150, is-locked: false}
                                              (map-get? loan-collateral loan-id))))
                (asserts! (>= (get deposited-amount collateral-info) withdrawal-amount) ERR_INSUFFICIENT_COLLATERAL)
                (asserts! (not (get is-locked collateral-info)) ERR_COLLATERAL_LOCKED)
                (let ((new-collateral-amount (- (get deposited-amount collateral-info) withdrawal-amount))
                      (new-ratio (if (> (get amount loan-data) u0)
                                   (/ (* new-collateral-amount u100) (get amount loan-data))
                                   u0)))
                    (map-set loan-collateral loan-id
                        (merge collateral-info {deposited-amount: new-collateral-amount}))
                    (map-set loans loan-id
                        (merge loan-data {collateral-amount: new-collateral-amount, collateral-ratio: new-ratio}))
                    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get borrower loan-data))))
                    (ok true))))
        ERR_LOAN_NOT_FOUND))

(define-public (liquidate-collateral (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (or (is-eq tx-sender (get borrower loan-data))
                         (is-eq (some tx-sender) (get cosigner loan-data))) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status loan-data) "defaulted") ERR_LOAN_NOT_ACTIVE)
            (let ((collateral-info (default-to {deposited-amount: u0, liquidation-threshold: u150, is-locked: false}
                                              (map-get? loan-collateral loan-id)))
                  (current-ratio (unwrap! (calculate-collateral-ratio loan-id) ERR_LOAN_NOT_FOUND)))
                (asserts! (< current-ratio (get liquidation-threshold collateral-info)) ERR_LIQUIDATION_THRESHOLD_NOT_MET)
                (let ((liquidation-amount (get deposited-amount collateral-info)))
                    (map-set loan-collateral loan-id
                        (merge collateral-info {deposited-amount: u0, is-locked: false}))
                    (map-set loans loan-id
                        (merge loan-data {collateral-amount: u0, collateral-ratio: u0}))
                    (match (get cosigner loan-data)
                        cosigner-principal (try! (as-contract (stx-transfer? liquidation-amount tx-sender cosigner-principal)))
                        (try! (as-contract (stx-transfer? liquidation-amount tx-sender CONTRACT_OWNER))))
                    (ok liquidation-amount))))
        ERR_LOAN_NOT_FOUND))

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
        (ok true)))

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender)))

(define-read-only (get-total-loans)
    (var-get loan-counter))

(define-read-only (get-loan-details (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (let ((payment-info (map-get? loan-payments loan-id))
              (collateral-info (map-get? loan-collateral loan-id))
              (total-due (+ (get amount loan-data) 
                           (/ (* (get amount loan-data) (get interest-rate loan-data)) u100))))
            (ok {
                loan: loan-data,
                payment-info: payment-info,
                collateral-info: collateral-info,
                total-due: total-due,
                remaining-balance: (- total-due (get repaid-amount loan-data)),
                is-overdue: (is-loan-overdue loan-id)
            }))
        ERR_LOAN_NOT_FOUND))
