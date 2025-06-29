;; title: Decentrlized-Identity-Refugees

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-IDENTITY-EXISTS (err u101))
(define-constant ERR-IDENTITY-NOT-FOUND (err u102))
(define-constant ERR-INVALID-SIGNATURE (err u103))
(define-constant ERR-EXPIRED-CERTIFICATE (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-ALREADY-VERIFIED (err u106))
(define-constant ERR-INVALID-VERIFIER (err u107))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant IDENTITY-CREATION-FEE u1000000)
(define-constant VERIFICATION-FEE u500000)
(define-constant CERTIFICATE-VALIDITY-BLOCKS u52560)

(define-data-var next-identity-id uint u1)

(define-map identities
  { identity-id: uint }
  {
    owner: principal,
    created-at: uint,
    updated-at: uint,
    is-verified: bool,
    verification-level: uint,
    status: (string-ascii 20)
  }
)

(define-map identity-data
  { identity-id: uint, data-key: (string-ascii 50) }
  { data-value: (string-ascii 500), encrypted: bool }
)

(define-map verifications
  { identity-id: uint, verifier: principal }
  {
    verified-at: uint,
    verification-type: (string-ascii 50),
    expiry-block: uint,
    signature: (buff 65)
  }
)

(define-map authorized-verifiers
  { verifier: principal }
  {
    authorized-at: uint,
    verification-types: (list 10 (string-ascii 50)),
    is-active: bool
  }
)

(define-map identity-recovery
  { identity-id: uint }
  {
    recovery-address: principal,
    recovery-initiated-at: uint,
    recovery-confirmed: bool
  }
)

(define-map trusted-guardians
  { identity-id: uint, guardian: principal }
  { added-at: uint, is-active: bool }
)

(define-public (create-identity (recovery-address principal))
  (let
    (
      (identity-id (var-get next-identity-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-none (get-identity-by-owner tx-sender)) ERR-IDENTITY-EXISTS)
    (try! (stx-transfer? IDENTITY-CREATION-FEE tx-sender CONTRACT-OWNER))
    
    (map-set identities
      { identity-id: identity-id }
      {
        owner: tx-sender,
        created-at: current-block,
        updated-at: current-block,
        is-verified: false,
        verification-level: u0,
        status: "active"
      }
    )
    
    (map-set identity-recovery
      { identity-id: identity-id }
      {
        recovery-address: recovery-address,
        recovery-initiated-at: u0,
        recovery-confirmed: false
      }
    )
    
    (var-set next-identity-id (+ identity-id u1))
    (ok identity-id)
  )
)

(define-public (update-identity-data (identity-id uint) (data-key (string-ascii 50)) (data-value (string-ascii 500)) (encrypted bool))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set identity-data
      { identity-id: identity-id, data-key: data-key }
      { data-value: data-value, encrypted: encrypted }
    )
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info { updated-at: current-block })
    )
    
    (ok true)
  )
)

(define-public (verify-identity (identity-id uint) (verification-type (string-ascii 50)) (signature (buff 65)))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-INVALID-VERIFIER))
      (current-block stacks-block-height)
      (expiry-block (+ current-block CERTIFICATE-VALIDITY-BLOCKS))
    )
    (asserts! (get is-active verifier-info) ERR-INVALID-VERIFIER)
    (asserts! (is-some (index-of (get verification-types verifier-info) verification-type)) ERR-INVALID-VERIFIER)
    (asserts! (is-none (map-get? verifications { identity-id: identity-id, verifier: tx-sender })) ERR-ALREADY-VERIFIED)
    
    (try! (stx-transfer? VERIFICATION-FEE (get owner identity-info) tx-sender))
    
    (map-set verifications
      { identity-id: identity-id, verifier: tx-sender }
      {
        verified-at: current-block,
        verification-type: verification-type,
        expiry-block: expiry-block,
        signature: signature
      }
    )
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info {
        is-verified: true,
        verification-level: (+ (get verification-level identity-info) u1),
        updated-at: current-block
      })
    )
    
    (ok true)
  )
)

(define-public (authorize-verifier (verifier principal) (verification-types (list 10 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized-at: stacks-block-height,
        verification-types: verification-types,
        is-active: true
      }
    )
    
    (ok true)
  )
)

(define-public (revoke-verifier (verifier principal))
  (let
    (
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: verifier }) ERR-INVALID-VERIFIER))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      (merge verifier-info { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (add-guardian (identity-id uint) (guardian principal))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set trusted-guardians
      { identity-id: identity-id, guardian: guardian }
      { added-at: stacks-block-height, is-active: true }
    )
    
    (ok true)
  )
)

(define-public (initiate-recovery (identity-id uint))
  (let
    (
      (recovery-info (unwrap! (map-get? identity-recovery { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
    )
    (asserts! (is-eq (get recovery-address recovery-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set identity-recovery
      { identity-id: identity-id }
      (merge recovery-info {
        recovery-initiated-at: stacks-block-height,
        recovery-confirmed: false
      })
    )
    
    (ok true)
  )
)

(define-public (confirm-recovery (identity-id uint))
  (let
    (
      (recovery-info (unwrap! (map-get? identity-recovery { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (recovery-blocks-passed (- stacks-block-height (get recovery-initiated-at recovery-info)))
    )
    (asserts! (is-eq (get recovery-address recovery-info) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (get recovery-initiated-at recovery-info) u0) ERR-NOT-AUTHORIZED)
    (asserts! (>= recovery-blocks-passed u144) ERR-NOT-AUTHORIZED)
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info { owner: tx-sender, updated-at: stacks-block-height })
    )
    
    (map-set identity-recovery
      { identity-id: identity-id }
      (merge recovery-info { recovery-confirmed: true })
    )
    
    (ok true)
  )
)

(define-public (transfer-identity (identity-id uint) (new-owner principal))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info { 
        owner: new-owner, 
        updated-at: stacks-block-height 
      })
    )
    
    (ok true)
  )
)

(define-read-only (get-identity (identity-id uint))
  (map-get? identities { identity-id: identity-id })
)

(define-read-only (get-identity-data (identity-id uint) (data-key (string-ascii 50)))
  (map-get? identity-data { identity-id: identity-id, data-key: data-key })
)

(define-read-only (get-verification (identity-id uint) (verifier principal))
  (map-get? verifications { identity-id: identity-id, verifier: verifier })
)

(define-read-only (get-verifier-info (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)

(define-read-only (get-recovery-info (identity-id uint))
  (map-get? identity-recovery { identity-id: identity-id })
)

(define-read-only (get-guardian-info (identity-id uint) (guardian principal))
  (map-get? trusted-guardians { identity-id: identity-id, guardian: guardian })
)

(define-read-only (is-verification-valid (identity-id uint) (verifier principal))
  (match (map-get? verifications { identity-id: identity-id, verifier: verifier })
    verification-info (< stacks-block-height (get expiry-block verification-info))
    false
  )
)

(define-read-only (get-identity-by-owner (owner principal))
  (let
    (
      (current-id (var-get next-identity-id))
    )
    (fold check-identity-owner (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) none)
  )
)

(define-private (check-identity-owner (id uint) (prev (optional uint)))
  (if (is-some prev)
    prev
    (match (map-get? identities { identity-id: id })
      identity-info (if (is-eq (get owner identity-info) tx-sender) (some id) none)
      none
    )
  )
)

(define-read-only (get-total-identities)
  (- (var-get next-identity-id) u1)
)
