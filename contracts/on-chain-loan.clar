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
(define-constant ERR_BID_NOT_FOUND (err u116))
(define-constant ERR_BID_ALREADY_EXISTS (err u117))
(define-constant ERR_BID_AMOUNT_MISMATCH (err u118))
(define-constant ERR_MARKETPLACE_CLOSED (err u119))
(define-constant ERR_INVALID_BID_RATE (err u120))
(define-constant ERR_TRANSFER_NOT_FOUND (err u121))
(define-constant ERR_TRANSFER_ALREADY_EXISTS (err u122))
(define-constant ERR_TRANSFER_TO_SELF (err u123))
(define-constant ERR_TRANSFER_ALREADY_APPROVED (err u124))
(define-constant ERR_INVALID_TRANSFER_AMOUNT (err u125))
(define-constant ERR_INVALID_RATING_TYPE (err u126))
(define-constant ERR_RATING_UPDATE_FAILED (err u127))
(define-constant ERR_AUTOPAY_ALREADY_ENABLED (err u128))
(define-constant ERR_AUTOPAY_NOT_ENABLED (err u129))
(define-constant ERR_AUTOPAY_EXECUTION_FAILED (err u130))
(define-constant ERR_REFINANCE_NOT_FOUND (err u131))
(define-constant ERR_REFINANCE_ALREADY_EXISTS (err u132))
(define-constant ERR_REFINANCE_EXPIRED (err u133))
(define-constant ERR_REFINANCE_NOT_ELIGIBLE (err u134))
(define-constant ERR_WORSE_TERMS (err u135))
(define-constant ERR_NO_FUNDS_TO_CLAIM (err u136))

(define-data-var loan-counter uint u0)
(define-data-var refinance-counter uint u0)

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

(define-map loan-bids {loan-id: uint, lender: principal} {
    interest-rate: uint,
    amount: uint,
    expires-at: uint,
    is-active: bool
})

(define-map loan-marketplace uint {
    is-open: bool,
    best-bid-rate: uint,
    best-bidder: (optional principal),
    bid-count: uint,
    expires-at: uint
})

(define-map loan-transfers {loan-id: uint, from-party: principal, to-party: principal} {
    transfer-amount: uint,
    transfer-fee: uint,
    approved: bool,
    created-at: uint,
    expires-at: uint
})

(define-map user-ratings principal {
    credit-score: uint,
    payment-reliability: uint,
    default-rate: uint,
    total-volume: uint,
    last-updated: uint,
    rating-tier: (string-ascii 10)
})

(define-map loan-ratings uint {
    risk-score: uint,
    expected-return: uint,
    borrower-rating: uint,
    cosigner-rating: uint,
    collateral-score: uint,
    final-rating: (string-ascii 10)
})

(define-map loan-autopay uint {
    enabled: bool,
    payment-amount: uint,
    frequency-blocks: uint,
    next-execution: uint,
    max-attempts: uint,
    current-attempts: uint,
    grace-period-blocks: uint,
    last-execution: (optional uint)
})

(define-map loan-refinancing uint {
    original-loan-id: uint,
    new-interest-rate: uint,
    new-duration-blocks: uint,
    remaining-balance: uint,
    proposed-by: principal,
    proposed-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    savings-amount: uint,
    new-cosigner: (optional principal)
})

(define-map repayment-claims uint uint)

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

(define-read-only (get-loan-bid (loan-id uint) (lender principal))
    (map-get? loan-bids {loan-id: loan-id, lender: lender}))

(define-read-only (get-loan-marketplace (loan-id uint))
    (map-get? loan-marketplace loan-id))

(define-read-only (get-loan-transfer (loan-id uint) (from-party principal) (to-party principal))
    (map-get? loan-transfers {loan-id: loan-id, from-party: from-party, to-party: to-party}))

(define-read-only (get-loan-autopay (loan-id uint))
    (map-get? loan-autopay loan-id))

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

(define-read-only (is-autopay-due (loan-id uint))
    (match (map-get? loan-autopay loan-id)
        autopay-data
        (and (get enabled autopay-data)
             (>= stacks-block-height (get next-execution autopay-data)))
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
        (map-set loan-marketplace loan-id {
            is-open: true,
            best-bid-rate: interest-rate,
            best-bidder: none,
            bid-count: u0,
            expires-at: (+ stacks-block-height u1008)
        })
        (ok loan-id)))

(define-public (enable-autopay (loan-id uint) (payment-amount uint) (frequency-blocks uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
            (asserts! (> payment-amount u0) ERR_INVALID_AMOUNT)
            (asserts! (and (>= frequency-blocks u144) (<= frequency-blocks u1008)) ERR_INVALID_DURATION)
            (asserts! (is-none (map-get? loan-autopay loan-id)) ERR_AUTOPAY_ALREADY_ENABLED)
            (map-set loan-autopay loan-id {
                enabled: true,
                payment-amount: payment-amount,
                frequency-blocks: frequency-blocks,
                next-execution: (+ stacks-block-height frequency-blocks),
                max-attempts: u3,
                current-attempts: u0,
                grace-period-blocks: u144,
                last-execution: none
            })
            (ok true))
        ERR_LOAN_NOT_FOUND))

(define-public (disable-autopay (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (match (map-get? loan-autopay loan-id)
                autopay-data
                (begin
                    (map-set loan-autopay loan-id
                        (merge autopay-data {enabled: false}))
                    (ok true))
                ERR_AUTOPAY_NOT_ENABLED))
        ERR_LOAN_NOT_FOUND))

(define-public (execute-autopay (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (match (map-get? loan-autopay loan-id)
            autopay-data
            (begin
                (asserts! (get enabled autopay-data) ERR_AUTOPAY_NOT_ENABLED)
                (asserts! (>= stacks-block-height (get next-execution autopay-data)) ERR_PAYMENT_TOO_EARLY)
                (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
                (let ((borrower-balance (stx-get-balance (get borrower loan-data)))
                      (payment-amount (get payment-amount autopay-data)))
                    (if (>= borrower-balance payment-amount)
                        (begin
                            (try! (stx-transfer? payment-amount (get borrower loan-data) (as-contract tx-sender)))
                            (let ((new-total-paid (+ (get repaid-amount loan-data) payment-amount))
                                  (total-amount-due (+ (get amount loan-data) 
                                                     (/ (* (get amount loan-data) (get interest-rate loan-data)) u100))))
                                (map-set loans loan-id
                                    (merge loan-data {
                                        repaid-amount: new-total-paid,
                                        status: (if (>= new-total-paid total-amount-due) "completed" "active"),
                                        last-payment: (some stacks-block-height)
                                    }))
                                (let ((payment-info (default-to {total-paid: u0, payments-made: u0, next-payment-due: u0}
                                                               (map-get? loan-payments loan-id))))
                                    (map-set loan-payments loan-id {
                                        total-paid: new-total-paid,
                                        payments-made: (+ (get payments-made payment-info) u1),
                                        next-payment-due: (+ stacks-block-height u1008)
                                    }))
                                (map-set loan-autopay loan-id
                                    (merge autopay-data {
                                        next-execution: (+ stacks-block-height (get frequency-blocks autopay-data)),
                                        current-attempts: u0,
                                        last-execution: (some stacks-block-height)
                                    }))
                                (ok true)))
                        (let ((new-attempts (+ (get current-attempts autopay-data) u1)))
                            (if (>= new-attempts (get max-attempts autopay-data))
                                (begin
                                    (map-set loan-autopay loan-id
                                        (merge autopay-data {
                                            enabled: false,
                                            current-attempts: new-attempts
                                        }))
                                    ERR_AUTOPAY_EXECUTION_FAILED)
                                (begin
                                    (map-set loan-autopay loan-id
                                        (merge autopay-data {
                                            next-execution: (+ stacks-block-height (get grace-period-blocks autopay-data)),
                                            current-attempts: new-attempts
                                        }))
                                    ERR_INSUFFICIENT_FUNDS))))))
            ERR_AUTOPAY_NOT_ENABLED)
        ERR_LOAN_NOT_FOUND))

(define-public (update-autopay-settings (loan-id uint) (payment-amount uint) (frequency-blocks uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (match (map-get? loan-autopay loan-id)
                autopay-data
                (begin
                    (asserts! (> payment-amount u0) ERR_INVALID_AMOUNT)
                    (asserts! (and (>= frequency-blocks u144) (<= frequency-blocks u1008)) ERR_INVALID_DURATION)
                    (map-set loan-autopay loan-id
                        (merge autopay-data {
                            payment-amount: payment-amount,
                            frequency-blocks: frequency-blocks,
                            next-execution: (+ stacks-block-height frequency-blocks)
                        }))
                    (ok true))
                ERR_AUTOPAY_NOT_ENABLED))
        ERR_LOAN_NOT_FOUND))


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
            (match (map-get? loan-autopay loan-id)
                autopay-data (map-set loan-autopay loan-id (merge autopay-data {enabled: false}))
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

(define-public (place-bid (loan-id uint) (bid-interest-rate uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_PENDING)
            (asserts! (<= bid-interest-rate u50) ERR_INVALID_BID_RATE)
            (asserts! (> bid-interest-rate u0) ERR_INVALID_BID_RATE)
            (let ((marketplace-data (default-to {is-open: false, best-bid-rate: u0, best-bidder: none, bid-count: u0, expires-at: u0}
                                               (map-get? loan-marketplace loan-id)))
                  (existing-bid (map-get? loan-bids {loan-id: loan-id, lender: tx-sender})))
                (asserts! (get is-open marketplace-data) ERR_MARKETPLACE_CLOSED)
                (asserts! (< stacks-block-height (get expires-at marketplace-data)) ERR_MARKETPLACE_CLOSED)
                (asserts! (is-none existing-bid) ERR_BID_ALREADY_EXISTS)
                (asserts! (< bid-interest-rate (get best-bid-rate marketplace-data)) ERR_INVALID_BID_RATE)
                (map-set loan-bids {loan-id: loan-id, lender: tx-sender} {
                    interest-rate: bid-interest-rate,
                    amount: (get amount loan-data),
                    expires-at: (+ stacks-block-height u5040),
                    is-active: true
                })
                (map-set loan-marketplace loan-id
                    (merge marketplace-data {
                        best-bid-rate: bid-interest-rate,
                        best-bidder: (some tx-sender),
                        bid-count: (+ (get bid-count marketplace-data) u1)
                    }))
                (ok true)))
        ERR_LOAN_NOT_FOUND))

(define-public (accept-bid (loan-id uint) (lender principal))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_PENDING)
            (let ((bid-data (unwrap! (map-get? loan-bids {loan-id: loan-id, lender: lender}) ERR_BID_NOT_FOUND))
                  (marketplace-data (unwrap! (map-get? loan-marketplace loan-id) ERR_LOAN_NOT_FOUND)))
                (asserts! (get is-active bid-data) ERR_BID_NOT_FOUND)
                (asserts! (< stacks-block-height (get expires-at bid-data)) ERR_BID_NOT_FOUND)
                (asserts! (is-eq (get amount bid-data) (get amount loan-data)) ERR_BID_AMOUNT_MISMATCH)
                (map-set loans loan-id
                    (merge loan-data {
                        interest-rate: (get interest-rate bid-data),
                        cosigner: (some lender),
                        status: "approved"
                    }))
                (map-set loan-marketplace loan-id
                    (merge marketplace-data {is-open: false}))
                (update-user-stats lender "loans-cosigned" (get amount loan-data))
                (ok true)))
        ERR_LOAN_NOT_FOUND))

(define-public (withdraw-bid (loan-id uint))
    (let ((bid-data (unwrap! (map-get? loan-bids {loan-id: loan-id, lender: tx-sender}) ERR_BID_NOT_FOUND)))
        (asserts! (get is-active bid-data) ERR_BID_NOT_FOUND)
        (map-set loan-bids {loan-id: loan-id, lender: tx-sender}
            (merge bid-data {is-active: false}))
        (match (map-get? loan-marketplace loan-id)
            marketplace-data
            (if (is-eq (some tx-sender) (get best-bidder marketplace-data))
                (map-set loan-marketplace loan-id
                    (merge marketplace-data {
                        best-bidder: none,
                        best-bid-rate: u50,
                        bid-count: (if (> (get bid-count marketplace-data) u0)
                                     (- (get bid-count marketplace-data) u1)
                                     u0)
                    }))
                true)
            true)
        (ok true)))

(define-public (close-marketplace (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
            (match (map-get? loan-marketplace loan-id)
                marketplace-data
                (begin
                    (map-set loan-marketplace loan-id
                        (merge marketplace-data {is-open: false}))
                    (ok true))
                ERR_LOAN_NOT_FOUND))
        ERR_LOAN_NOT_FOUND))

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
        (ok true)))

(define-public (initiate-loan-transfer (loan-id uint) (to-party principal) (transfer-amount uint) (transfer-fee uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (not (is-eq tx-sender to-party)) ERR_TRANSFER_TO_SELF)
            (asserts! (is-eq (some tx-sender) (get cosigner loan-data)) ERR_UNAUTHORIZED)
            (asserts! (or (is-eq (get status loan-data) "active") (is-eq (get status loan-data) "approved")) ERR_LOAN_NOT_ACTIVE)
            (asserts! (> transfer-amount u0) ERR_INVALID_TRANSFER_AMOUNT)
            (asserts! (is-none (map-get? loan-transfers {loan-id: loan-id, from-party: tx-sender, to-party: to-party})) ERR_TRANSFER_ALREADY_EXISTS)
            (map-set loan-transfers {loan-id: loan-id, from-party: tx-sender, to-party: to-party} {
                transfer-amount: transfer-amount,
                transfer-fee: transfer-fee,
                approved: false,
                created-at: stacks-block-height,
                expires-at: (+ stacks-block-height u1008)
            })
            (ok true))
        ERR_LOAN_NOT_FOUND))

(define-public (approve-loan-transfer (loan-id uint) (from-party principal))
    (let ((transfer-key {loan-id: loan-id, from-party: from-party, to-party: tx-sender}))
        (match (map-get? loan-transfers transfer-key)
            transfer-data
            (begin
                (asserts! (not (get approved transfer-data)) ERR_TRANSFER_ALREADY_APPROVED)
                (asserts! (< stacks-block-height (get expires-at transfer-data)) ERR_TRANSFER_NOT_FOUND)
                (asserts! (>= (stx-get-balance tx-sender) (+ (get transfer-amount transfer-data) (get transfer-fee transfer-data))) ERR_INSUFFICIENT_FUNDS)
                (try! (stx-transfer? (get transfer-amount transfer-data) tx-sender from-party))
                (if (> (get transfer-fee transfer-data) u0)
                    (try! (stx-transfer? (get transfer-fee transfer-data) tx-sender CONTRACT_OWNER))
                    true)
                (map-set loan-transfers transfer-key
                    (merge transfer-data {approved: true}))
                (ok true))
            ERR_TRANSFER_NOT_FOUND)))

(define-public (execute-loan-transfer (loan-id uint) (from-party principal) (to-party principal))
    (let ((transfer-key {loan-id: loan-id, from-party: from-party, to-party: to-party}))
        (match (map-get? loan-transfers transfer-key)
            transfer-data
            (begin
                (asserts! (get approved transfer-data) ERR_TRANSFER_NOT_FOUND)
                (asserts! (< stacks-block-height (get expires-at transfer-data)) ERR_TRANSFER_NOT_FOUND)
                (match (map-get? loans loan-id)
                    loan-data
                    (begin
                        (asserts! (is-eq (some from-party) (get cosigner loan-data)) ERR_UNAUTHORIZED)
                        (map-set loans loan-id
                            (merge loan-data {cosigner: (some to-party)}))
                        (let ((current-from-stats (get-user-stats from-party))
                              (current-to-stats (get-user-stats to-party)))
                            (map-set user-stats from-party
                                (merge current-from-stats {
                                    loans-cosigned: (if (> (get loans-cosigned current-from-stats) u0)
                                                      (- (get loans-cosigned current-from-stats) u1)
                                                      u0),
                                    total-cosigned: (if (>= (get total-cosigned current-from-stats) (get amount loan-data))
                                                      (- (get total-cosigned current-from-stats) (get amount loan-data))
                                                      u0)
                                }))
                            (map-set user-stats to-party
                                (merge current-to-stats {
                                    loans-cosigned: (+ (get loans-cosigned current-to-stats) u1),
                                    total-cosigned: (+ (get total-cosigned current-to-stats) (get amount loan-data))
                                })))
                        (map-delete loan-transfers transfer-key)
                        (ok true))
                    ERR_LOAN_NOT_FOUND))
            ERR_TRANSFER_NOT_FOUND)))

(define-public (cancel-loan-transfer (loan-id uint) (to-party principal))
    (let ((transfer-key {loan-id: loan-id, from-party: tx-sender, to-party: to-party}))
        (match (map-get? loan-transfers transfer-key)
            transfer-data
            (begin
                (asserts! (not (get approved transfer-data)) ERR_TRANSFER_ALREADY_APPROVED)
                (map-delete loan-transfers transfer-key)
                (ok true))
            ERR_TRANSFER_NOT_FOUND)))

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender)))

(define-read-only (get-total-loans)
    (var-get loan-counter))

(define-read-only (get-loan-details (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (let ((payment-info (map-get? loan-payments loan-id))
              (collateral-info (map-get? loan-collateral loan-id))
              (autopay-info (map-get? loan-autopay loan-id))
              (total-due (+ (get amount loan-data) 
                           (/ (* (get amount loan-data) (get interest-rate loan-data)) u100))))
            (ok {
                loan: loan-data,
                payment-info: payment-info,
                collateral-info: collateral-info,
                autopay-info: autopay-info,
                total-due: total-due,
                remaining-balance: (- total-due (get repaid-amount loan-data)),
                is-overdue: (is-loan-overdue loan-id),
                is-autopay-due: (is-autopay-due loan-id)
            }))
        ERR_LOAN_NOT_FOUND))

(define-read-only (get-refinance-offer (refinance-id uint))
    (map-get? loan-refinancing refinance-id))

(define-read-only (calculate-refinance-savings (original-loan-id uint) (new-interest-rate uint))
    (match (map-get? loans original-loan-id)
        loan-data
        (let ((total-due (+ (get amount loan-data) 
                           (/ (* (get amount loan-data) (get interest-rate loan-data)) u100)))
              (remaining-balance (- total-due (get repaid-amount loan-data)))
              (original-interest (/ (* remaining-balance (get interest-rate loan-data)) u100))
              (new-interest (/ (* remaining-balance new-interest-rate) u100)))
            (ok (if (> original-interest new-interest)
                   (- original-interest new-interest)
                   u0)))
        ERR_LOAN_NOT_FOUND))

(define-read-only (is-refinance-eligible (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (let ((payment-info (default-to {total-paid: u0, payments-made: u0, next-payment-due: u0}
                                       (map-get? loan-payments loan-id))))
            (and (is-eq (get status loan-data) "active")
                 (>= (get payments-made payment-info) u3)
                 (not (is-loan-overdue loan-id))
                 (> (get repaid-amount loan-data) u0)))
        false))

(define-public (propose-refinance (loan-id uint) (new-interest-rate uint) (new-duration-blocks uint))
    (match (map-get? loans loan-id)
        loan-data
        (begin
            (asserts! (is-eq (some tx-sender) (get cosigner loan-data)) ERR_UNAUTHORIZED)
            (asserts! (is-refinance-eligible loan-id) ERR_REFINANCE_NOT_ELIGIBLE)
            (asserts! (< new-interest-rate (get interest-rate loan-data)) ERR_WORSE_TERMS)
            (asserts! (<= new-interest-rate u50) ERR_INVALID_INTEREST)
            (asserts! (and (>= new-duration-blocks u1008) (<= new-duration-blocks u52560)) ERR_INVALID_DURATION)
            (let ((refinance-id (+ (var-get refinance-counter) u1))
                  (total-due (+ (get amount loan-data) 
                               (/ (* (get amount loan-data) (get interest-rate loan-data)) u100)))
                  (remaining-balance (- total-due (get repaid-amount loan-data)))
                  (savings (unwrap! (calculate-refinance-savings loan-id new-interest-rate) ERR_LOAN_NOT_FOUND)))
                (map-set loan-refinancing refinance-id {
                    original-loan-id: loan-id,
                    new-interest-rate: new-interest-rate,
                    new-duration-blocks: new-duration-blocks,
                    remaining-balance: remaining-balance,
                    proposed-by: tx-sender,
                    proposed-at: stacks-block-height,
                    expires-at: (+ stacks-block-height u1008),
                    status: "pending",
                    savings-amount: savings,
                    new-cosigner: (some tx-sender)
                })
                (var-set refinance-counter refinance-id)
                (ok refinance-id)))
        ERR_LOAN_NOT_FOUND))

(define-public (accept-refinance (refinance-id uint))
    (match (map-get? loan-refinancing refinance-id)
        refinance-data
        (let ((loan-id (get original-loan-id refinance-data)))
            (match (map-get? loans loan-id)
                loan-data
                (begin
                    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
                    (asserts! (is-eq (get status refinance-data) "pending") ERR_REFINANCE_EXPIRED)
                    (asserts! (< stacks-block-height (get expires-at refinance-data)) ERR_REFINANCE_EXPIRED)
                    (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
                    (let ((payment-info (default-to {total-paid: u0, payments-made: u0, next-payment-due: u0}
                                                   (map-get? loan-payments loan-id)))
                          (old-cosigner (get cosigner loan-data))
                          (new-cosigner (get new-cosigner refinance-data)))
                        (map-set loans loan-id
                            (merge loan-data {
                                interest-rate: (get new-interest-rate refinance-data),
                                duration-blocks: (get new-duration-blocks refinance-data),
                                cosigner: new-cosigner,
                                amount: (get remaining-balance refinance-data)
                            }))
                        (map-set loan-payments loan-id
                            (merge payment-info {
                                total-paid: u0,
                                payments-made: u0,
                                next-payment-due: (+ stacks-block-height u1008)
                            }))
                        (map-set loan-refinancing refinance-id
                            (merge refinance-data {status: "accepted"}))
                        (match old-cosigner
                            old-principal
                            (let ((old-stats (get-user-stats old-principal)))
                                (map-set user-stats old-principal
                                    (merge old-stats {
                                        loans-cosigned: (if (> (get loans-cosigned old-stats) u0)
                                                          (- (get loans-cosigned old-stats) u1)
                                                          u0)
                                    })))
                            true)
                        (ok true)))
                ERR_LOAN_NOT_FOUND))
        ERR_REFINANCE_NOT_FOUND))

(define-public (reject-refinance (refinance-id uint))
    (match (map-get? loan-refinancing refinance-id)
        refinance-data
        (let ((loan-id (get original-loan-id refinance-data)))
            (match (map-get? loans loan-id)
                loan-data
                (begin
                    (asserts! (is-eq (get borrower loan-data) tx-sender) ERR_UNAUTHORIZED)
                    (asserts! (is-eq (get status refinance-data) "pending") ERR_REFINANCE_EXPIRED)
                    (map-set loan-refinancing refinance-id
                        (merge refinance-data {status: "rejected"}))
                    (ok true))
                ERR_LOAN_NOT_FOUND))
        ERR_REFINANCE_NOT_FOUND))

(define-public (cancel-refinance (refinance-id uint))
    (match (map-get? loan-refinancing refinance-id)
        refinance-data
        (begin
            (asserts! (is-eq (get proposed-by refinance-data) tx-sender) ERR_UNAUTHORIZED)
            (asserts! (is-eq (get status refinance-data) "pending") ERR_REFINANCE_EXPIRED)
            (map-set loan-refinancing refinance-id
                (merge refinance-data {status: "cancelled"}))
            (ok true))
        ERR_REFINANCE_NOT_FOUND))

(define-read-only (get-total-refinances)
    (var-get refinance-counter))

(define-public (claim-loan-payment (loan-id uint))
    (match (map-get? loans loan-id)
        loan-data
        (match (get cosigner loan-data)
            lender
            (begin
                (asserts! (is-eq tx-sender lender) ERR_UNAUTHORIZED)
                (let ((repaid (get repaid-amount loan-data))
                      (claimed (default-to u0 (map-get? repayment-claims loan-id)))
                      (claimable (- repaid claimed)))
                    (asserts! (> claimable u0) ERR_NO_FUNDS_TO_CLAIM)
                    (try! (as-contract (stx-transfer? claimable tx-sender lender)))
                    (map-set repayment-claims loan-id repaid)
                    (ok claimable)))
            ERR_NOT_COSIGNER)
        ERR_LOAN_NOT_FOUND))
