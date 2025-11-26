;; title: Decentrlized-Identity-Refugees

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-IDENTITY-EXISTS (err u101))
(define-constant ERR-IDENTITY-NOT-FOUND (err u102))
(define-constant ERR-INVALID-SIGNATURE (err u103))
(define-constant ERR-EXPIRED-CERTIFICATE (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-ALREADY-VERIFIED (err u106))
(define-constant ERR-INVALID-VERIFIER (err u107))
(define-constant ERR-IDENTITY-INACTIVE (err u108))
(define-constant ERR-IDENTITY-SUSPENDED (err u109))
(define-constant ERR-SELF-ENDORSEMENT (err u110))
(define-constant ERR-ALREADY-ENDORSED (err u111))
(define-constant ERR-ENDORSEMENT-COOLDOWN (err u112))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u113))
(define-constant ERR-INVALID-ISSUER (err u114))
(define-constant ERR-CREDENTIAL-EXPIRED (err u115))
(define-constant ERR-CREDENTIAL-EXISTS (err u116))
(define-constant ERR-CREDENTIAL-REVOKED (err u117))
(define-constant ERR-EMERGENCY-CONTACT-EXISTS (err u118))
(define-constant ERR-EMERGENCY-CONTACT-NOT-FOUND (err u119))
(define-constant ERR-MAX-CONTACTS-REACHED (err u120))
(define-constant ERR-EMERGENCY-NOT-ACTIVE (err u121))
(define-constant ERR-EMERGENCY-ALREADY-ACTIVE (err u122))
(define-constant ERR-CONTACT-ALREADY-RESPONDED (err u123))
(define-constant ERR-DELEGATE-ALREADY-EXISTS (err u124))
(define-constant ERR-DELEGATE-NOT-FOUND (err u125))
(define-constant ERR-DELEGATION-EXPIRED (err u126))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant IDENTITY-CREATION-FEE u1000000)
(define-constant VERIFICATION-FEE u500000)
(define-constant CERTIFICATE-VALIDITY-BLOCKS u52560)
(define-constant IDENTITY-INACTIVITY-BLOCKS u157680)
(define-constant SUSPENSION-COOLDOWN-BLOCKS u2016)
(define-constant ENDORSEMENT-COOLDOWN-BLOCKS u144)
(define-constant CREDENTIAL-VALIDITY-BLOCKS u262800)

(define-data-var next-identity-id uint u1)
(define-data-var next-credential-id uint u1)
(define-data-var next-emergency-id uint u1)

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

(define-map identity-suspensions
  { identity-id: uint }
  {
    suspended-at: uint,
    suspended-by: principal,
    reason: (string-ascii 100),
    can-reactivate-at: uint
  }
)

(define-map identity-endorsements
  { identity-id: uint, endorser: principal }
  {
    endorsed-at: uint,
    endorsement-type: (string-ascii 50),
    message: (string-ascii 200)
  }
)

(define-map endorsement-history
  { endorser: principal, target-id: uint }
  { last-endorsed-at: uint }
)

(define-map reputation-scores
  { identity-id: uint }
  {
    total-endorsements: uint,
    positive-score: uint,
    negative-score: uint,
    last-calculated-at: uint
  }
)

(define-map credential-issuers
  { issuer: principal }
  {
    authorized-at: uint,
    issuer-name: (string-ascii 100),
    credential-types: (list 20 (string-ascii 50)),
    is-active: bool
  }
)

(define-map credentials
  { credential-id: uint }
  {
    holder-id: uint,
    issuer: principal,
    credential-type: (string-ascii 50),
    credential-name: (string-ascii 100),
    issued-at: uint,
    expires-at: uint,
    metadata: (string-ascii 500),
    is-revoked: bool,
    revoked-at: uint
  }
)

(define-map identity-credentials
  { identity-id: uint, credential-type: (string-ascii 50) }
  { credential-ids: (list 50 uint) }
)

(define-map emergency-contacts
  { identity-id: uint, contact: principal }
  {
    added-at: uint,
    contact-type: (string-ascii 30),
    priority-level: uint,
    can-receive-alerts: bool,
    last-notified: uint
  }
)

(define-map emergency-alerts
  { emergency-id: uint }
  {
    identity-id: uint,
    activated-at: uint,
    resolved-at: uint,
    alert-type: (string-ascii 50),
    message: (string-ascii 300),
    location-data: (optional (string-ascii 200)),
    is-active: bool,
    responder-count: uint
  }
)

(define-map alert-responses
  { emergency-id: uint, responder: principal }
  {
    responded-at: uint,
    response-type: (string-ascii 30),
    assistance-offered: (string-ascii 200),
    location-shared: bool
  }
)

(define-map identity-emergency-contacts
  { identity-id: uint }
  { contacts: (list 20 principal), total-count: uint }
)

(define-map data-delegates
  { identity-id: uint, delegate: principal, data-key: (string-ascii 50) }
  { authorized-at: uint, expires-at: uint }
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
    (asserts! (is-identity-active identity-id) ERR-IDENTITY-INACTIVE)
    
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

(define-public (suspend-identity (identity-id uint) (reason (string-ascii 100)))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
      (reactivation-block (+ current-block SUSPENSION-COOLDOWN-BLOCKS))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? identity-suspensions { identity-id: identity-id })) ERR-IDENTITY-SUSPENDED)
    
    (map-set identity-suspensions
      { identity-id: identity-id }
      {
        suspended-at: current-block,
        suspended-by: tx-sender,
        reason: reason,
        can-reactivate-at: reactivation-block
      }
    )
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info {
        status: "suspended",
        updated-at: current-block
      })
    )
    
    (ok true)
  )
)

(define-public (reactivate-identity (identity-id uint))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (suspension-info (unwrap! (map-get? identity-suspensions { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
      (inactivity-threshold (- current-block IDENTITY-INACTIVITY-BLOCKS))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= current-block (get can-reactivate-at suspension-info)) ERR-NOT-AUTHORIZED)
    
    (map-delete identity-suspensions { identity-id: identity-id })
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info {
        status: "active",
        updated-at: current-block
      })
    )
    
    (ok true)
  )
)

(define-public (deactivate-inactive-identity (identity-id uint))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
      (inactivity-threshold (- current-block IDENTITY-INACTIVITY-BLOCKS))
    )
    (asserts! (< (get updated-at identity-info) inactivity-threshold) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status identity-info) "active") ERR-IDENTITY-INACTIVE)
    
    (map-set identities
      { identity-id: identity-id }
      (merge identity-info {
        status: "inactive",
        updated-at: current-block
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

(define-read-only (get-suspension-info (identity-id uint))
  (map-get? identity-suspensions { identity-id: identity-id })
)

(define-read-only (is-identity-active (identity-id uint))
  (match (map-get? identities { identity-id: identity-id })
    identity-info
      (let
        (
          (status-check (is-eq (get status identity-info) "active"))
          (suspension-check (is-none (map-get? identity-suspensions { identity-id: identity-id })))
          (inactivity-threshold (- stacks-block-height IDENTITY-INACTIVITY-BLOCKS))
          (activity-check (> (get updated-at identity-info) inactivity-threshold))
        )
        (and status-check suspension-check activity-check)
      )
    false
  )
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

(define-public (endorse-identity (target-id uint) (endorsement-type (string-ascii 50)) (message (string-ascii 200)))
  (let
    (
      (endorser-id-opt (get-identity-by-owner tx-sender))
      (target-identity (unwrap! (map-get? identities { identity-id: target-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
      (history-key { endorser: tx-sender, target-id: target-id })
      (last-endorsement (map-get? endorsement-history history-key))
    )
    (asserts! (is-some endorser-id-opt) ERR-IDENTITY-NOT-FOUND)
    (asserts! (not (is-eq (get owner target-identity) tx-sender)) ERR-SELF-ENDORSEMENT)
    (asserts! (is-identity-active target-id) ERR-IDENTITY-INACTIVE)
    (asserts! (is-identity-active (unwrap-panic endorser-id-opt)) ERR-IDENTITY-INACTIVE)
    (asserts! (is-none (map-get? identity-endorsements { identity-id: target-id, endorser: tx-sender })) ERR-ALREADY-ENDORSED)
    
    (match last-endorsement
      history-data
        (asserts! 
          (>= (- current-block (get last-endorsed-at history-data)) ENDORSEMENT-COOLDOWN-BLOCKS) 
          ERR-ENDORSEMENT-COOLDOWN
        )
      true
    )
    
    (map-set identity-endorsements
      { identity-id: target-id, endorser: tx-sender }
      {
        endorsed-at: current-block,
        endorsement-type: endorsement-type,
        message: message
      }
    )
    
    (map-set endorsement-history
      history-key
      { last-endorsed-at: current-block }
    )
    
    (unwrap-panic (update-reputation-score target-id endorsement-type))
    
    (ok true)
  )
)

(define-public (remove-endorsement (target-id uint))
  (let
    (
      (endorser-id-opt (get-identity-by-owner tx-sender))
      (endorsement-key { identity-id: target-id, endorser: tx-sender })
      (existing-endorsement (unwrap! (map-get? identity-endorsements endorsement-key) ERR-IDENTITY-NOT-FOUND))
    )
    (asserts! (is-some endorser-id-opt) ERR-IDENTITY-NOT-FOUND)
    
    (map-delete identity-endorsements endorsement-key)
    
    (unwrap-panic (update-reputation-score target-id (get endorsement-type existing-endorsement)))
    
    (ok true)
  )
)

(define-private (update-reputation-score (identity-id uint) (endorsement-type (string-ascii 50)))
  (let
    (
      (current-score (default-to 
        { total-endorsements: u0, positive-score: u0, negative-score: u0, last-calculated-at: u0 }
        (map-get? reputation-scores { identity-id: identity-id })
      ))
      (score-change (if (is-eq endorsement-type "positive") u10 
                    (if (is-eq endorsement-type "neutral") u5 u1)))
      (current-block stacks-block-height)
    )
    (map-set reputation-scores
      { identity-id: identity-id }
      {
        total-endorsements: (+ (get total-endorsements current-score) u1),
        positive-score: (if (is-eq endorsement-type "positive") 
                         (+ (get positive-score current-score) score-change)
                         (get positive-score current-score)),
        negative-score: (if (is-eq endorsement-type "negative") 
                         (+ (get negative-score current-score) score-change)
                         (get negative-score current-score)),
        last-calculated-at: current-block
      }
    )
    (ok true)
  )
)

(define-read-only (get-endorsement (identity-id uint) (endorser principal))
  (map-get? identity-endorsements { identity-id: identity-id, endorser: endorser })
)

(define-read-only (get-reputation-score (identity-id uint))
  (default-to 
    { total-endorsements: u0, positive-score: u0, negative-score: u0, last-calculated-at: u0 }
    (map-get? reputation-scores { identity-id: identity-id })
  )
)

(define-read-only (calculate-trust-score (identity-id uint))
  (let
    (
      (reputation (get-reputation-score identity-id))
      (total-endorsements (get total-endorsements reputation))
      (positive-score (get positive-score reputation))
      (negative-score (get negative-score reputation))
    )
    (if (is-eq total-endorsements u0)
      u0
      (if (>= positive-score negative-score)
        (/ (* positive-score u100) (+ positive-score negative-score))
        (/ (* negative-score u100) (+ positive-score negative-score))
      )
    )
  )
)

(define-read-only (get-total-identities)
  (- (var-get next-identity-id) u1)
)

(define-public (authorize-credential-issuer (issuer principal) (issuer-name (string-ascii 100)) (credential-types (list 20 (string-ascii 50))))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set credential-issuers
      { issuer: issuer }
      {
        authorized-at: stacks-block-height,
        issuer-name: issuer-name,
        credential-types: credential-types,
        is-active: true
      }
    )
    
    (ok true)
  )
)

(define-public (revoke-credential-issuer (issuer principal))
  (let
    (
      (issuer-info (unwrap! (map-get? credential-issuers { issuer: issuer }) ERR-INVALID-ISSUER))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set credential-issuers
      { issuer: issuer }
      (merge issuer-info { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (issue-credential (holder-id uint) (credential-type (string-ascii 50)) (credential-name (string-ascii 100)) (metadata (string-ascii 500)))
  (let
    (
      (credential-id (var-get next-credential-id))
      (issuer-info (unwrap! (map-get? credential-issuers { issuer: tx-sender }) ERR-INVALID-ISSUER))
      (holder-identity (unwrap! (map-get? identities { identity-id: holder-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
      (expires-at (+ current-block CREDENTIAL-VALIDITY-BLOCKS))
      (credentials-key { identity-id: holder-id, credential-type: credential-type })
      (existing-credentials (default-to (list) (get credential-ids (map-get? identity-credentials credentials-key))))
    )
    (asserts! (get is-active issuer-info) ERR-INVALID-ISSUER)
    (asserts! (is-some (index-of (get credential-types issuer-info) credential-type)) ERR-INVALID-ISSUER)
    (asserts! (is-identity-active holder-id) ERR-IDENTITY-INACTIVE)
    
    (map-set credentials
      { credential-id: credential-id }
      {
        holder-id: holder-id,
        issuer: tx-sender,
        credential-type: credential-type,
        credential-name: credential-name,
        issued-at: current-block,
        expires-at: expires-at,
        metadata: metadata,
        is-revoked: false,
        revoked-at: u0
      }
    )
    
    (map-set identity-credentials
      credentials-key
      { credential-ids: (unwrap! (as-max-len? (append existing-credentials credential-id) u50) ERR-INSUFFICIENT-BALANCE) }
    )
    
    (var-set next-credential-id (+ credential-id u1))
    (ok credential-id)
  )
)

(define-public (revoke-credential (credential-id uint))
  (let
    (
      (credential-info (unwrap! (map-get? credentials { credential-id: credential-id }) ERR-CREDENTIAL-NOT-FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get issuer credential-info)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-revoked credential-info)) ERR-CREDENTIAL-REVOKED)
    
    (map-set credentials
      { credential-id: credential-id }
      (merge credential-info {
        is-revoked: true,
        revoked-at: current-block
      })
    )
    
    (ok true)
  )
)

(define-read-only (get-credential (credential-id uint))
  (map-get? credentials { credential-id: credential-id })
)

(define-read-only (get-credential-issuer (issuer principal))
  (map-get? credential-issuers { issuer: issuer })
)

(define-read-only (get-identity-credentials (identity-id uint) (credential-type (string-ascii 50)))
  (default-to (list) (get credential-ids (map-get? identity-credentials { identity-id: identity-id, credential-type: credential-type })))
)

(define-read-only (is-credential-valid (credential-id uint))
  (match (map-get? credentials { credential-id: credential-id })
    credential-info
      (let
        (
          (not-revoked (not (get is-revoked credential-info)))
          (not-expired (> (get expires-at credential-info) stacks-block-height))
          (holder-active (is-identity-active (get holder-id credential-info)))
          (issuer-active (match (map-get? credential-issuers { issuer: (get issuer credential-info) })
                           issuer-data (get is-active issuer-data)
                           false))
        )
        (and not-revoked not-expired holder-active issuer-active)
      )
    false
  )
)

(define-read-only (verify-credential-authenticity (credential-id uint))
  (match (map-get? credentials { credential-id: credential-id })
    credential-info
      (let
        (
          (issuer-info (map-get? credential-issuers { issuer: (get issuer credential-info) }))
          (valid-credential (is-credential-valid credential-id))
        )
        {
          is-authentic: valid-credential,
          issuer-verified: (is-some issuer-info),
          credential-data: (some credential-info)
        }
      )
    {
      is-authentic: false,
      issuer-verified: false,
      credential-data: none
    }
  )
)

(define-read-only (get-identity-credential-count (identity-id uint))
  (let
    (
      (education-creds (len (get-identity-credentials identity-id "education")))
      (professional-creds (len (get-identity-credentials identity-id "professional")))
      (skill-creds (len (get-identity-credentials identity-id "skill")))
      (certification-creds (len (get-identity-credentials identity-id "certification")))
    )
    {
      education: education-creds,
      professional: professional-creds,
      skill: skill-creds,
      certification: certification-creds,
      total: (+ education-creds professional-creds skill-creds certification-creds)
    }
  )
)

(define-public (add-emergency-contact (identity-id uint) (contact principal) (contact-type (string-ascii 30)) (priority-level uint))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (contacts-data (default-to { contacts: (list), total-count: u0 } 
                       (map-get? identity-emergency-contacts { identity-id: identity-id })))
      (current-contacts (get contacts contacts-data))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-identity-active identity-id) ERR-IDENTITY-INACTIVE)
    (asserts! (is-none (map-get? emergency-contacts { identity-id: identity-id, contact: contact })) ERR-EMERGENCY-CONTACT-EXISTS)
    (asserts! (< (get total-count contacts-data) u20) ERR-MAX-CONTACTS-REACHED)
    (asserts! (<= priority-level u5) ERR-NOT-AUTHORIZED)
    
    (map-set emergency-contacts
      { identity-id: identity-id, contact: contact }
      {
        added-at: current-block,
        contact-type: contact-type,
        priority-level: priority-level,
        can-receive-alerts: true,
        last-notified: u0
      }
    )
    
    (map-set identity-emergency-contacts
      { identity-id: identity-id }
      {
        contacts: (unwrap! (as-max-len? (append current-contacts contact) u20) ERR-MAX-CONTACTS-REACHED),
        total-count: (+ (get total-count contacts-data) u1)
      }
    )
    
    (ok true)
  )
)

(define-public (remove-emergency-contact (identity-id uint) (contact principal))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (contact-info (unwrap! (map-get? emergency-contacts { identity-id: identity-id, contact: contact }) ERR-EMERGENCY-CONTACT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-delete emergency-contacts { identity-id: identity-id, contact: contact })
    
    (ok true)
  )
)

(define-public (update-contact-alert-permission (identity-id uint) (contact principal) (can-receive bool))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (contact-info (unwrap! (map-get? emergency-contacts { identity-id: identity-id, contact: contact }) ERR-EMERGENCY-CONTACT-NOT-FOUND))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set emergency-contacts
      { identity-id: identity-id, contact: contact }
      (merge contact-info { can-receive-alerts: can-receive })
    )
    
    (ok true)
  )
)

(define-public (activate-emergency-alert (identity-id uint) (alert-type (string-ascii 50)) (message (string-ascii 300)) (location-data (optional (string-ascii 200))))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (emergency-id (var-get next-emergency-id))
      (current-block stacks-block-height)
      (contacts-data (default-to { contacts: (list), total-count: u0 } 
                       (map-get? identity-emergency-contacts { identity-id: identity-id })))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-identity-active identity-id) ERR-IDENTITY-INACTIVE)
    (asserts! (> (get total-count contacts-data) u0) ERR-EMERGENCY-CONTACT-NOT-FOUND)
    
    (map-set emergency-alerts
      { emergency-id: emergency-id }
      {
        identity-id: identity-id,
        activated-at: current-block,
        resolved-at: u0,
        alert-type: alert-type,
        message: message,
        location-data: location-data,
        is-active: true,
        responder-count: u0
      }
    )
    
    (unwrap-panic (notify-emergency-contacts identity-id emergency-id))
    
    (var-set next-emergency-id (+ emergency-id u1))
    (ok emergency-id)
  )
)

(define-private (notify-emergency-contacts (identity-id uint) (emergency-id uint))
  (let
    (
      (contacts-data (default-to { contacts: (list), total-count: u0 } 
                       (map-get? identity-emergency-contacts { identity-id: identity-id })))
      (current-block stacks-block-height)
    )
    (fold update-contact-notification (get contacts contacts-data) { id: identity-id, block: current-block })
    (ok true)
  )
)

(define-private (update-contact-notification (contact principal) (context { id: uint, block: uint }))
  (match (map-get? emergency-contacts { identity-id: (get id context), contact: contact })
    contact-info
      (if (get can-receive-alerts contact-info)
        (begin
          (map-set emergency-contacts
            { identity-id: (get id context), contact: contact }
            (merge contact-info { last-notified: (get block context) })
          )
          context
        )
        context
      )
    context
  )
)

(define-public (respond-to-emergency (emergency-id uint) (response-type (string-ascii 30)) (assistance-offered (string-ascii 200)) (share-location bool))
  (let
    (
      (alert-info (unwrap! (map-get? emergency-alerts { emergency-id: emergency-id }) ERR-EMERGENCY-NOT-ACTIVE))
      (identity-id (get identity-id alert-info))
      (contact-info (unwrap! (map-get? emergency-contacts { identity-id: identity-id, contact: tx-sender }) ERR-EMERGENCY-CONTACT-NOT-FOUND))
      (existing-response (map-get? alert-responses { emergency-id: emergency-id, responder: tx-sender }))
      (current-block stacks-block-height)
    )
    (asserts! (get is-active alert-info) ERR-EMERGENCY-NOT-ACTIVE)
    (asserts! (is-none existing-response) ERR-CONTACT-ALREADY-RESPONDED)
    (asserts! (get can-receive-alerts contact-info) ERR-NOT-AUTHORIZED)
    
    (map-set alert-responses
      { emergency-id: emergency-id, responder: tx-sender }
      {
        responded-at: current-block,
        response-type: response-type,
        assistance-offered: assistance-offered,
        location-shared: share-location
      }
    )
    
    (map-set emergency-alerts
      { emergency-id: emergency-id }
      (merge alert-info { responder-count: (+ (get responder-count alert-info) u1) })
    )
    
    (ok true)
  )
)

(define-public (resolve-emergency-alert (emergency-id uint))
  (let
    (
      (alert-info (unwrap! (map-get? emergency-alerts { emergency-id: emergency-id }) ERR-EMERGENCY-NOT-ACTIVE))
      (identity-info (unwrap! (map-get? identities { identity-id: (get identity-id alert-info) }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active alert-info) ERR-EMERGENCY-NOT-ACTIVE)
    
    (map-set emergency-alerts
      { emergency-id: emergency-id }
      (merge alert-info {
        is-active: false,
        resolved-at: current-block
      })
    )
    
    (ok true)
  )
)

(define-read-only (get-emergency-contact (identity-id uint) (contact principal))
  (map-get? emergency-contacts { identity-id: identity-id, contact: contact })
)

(define-read-only (get-identity-emergency-contacts (identity-id uint))
  (default-to { contacts: (list), total-count: u0 }
    (map-get? identity-emergency-contacts { identity-id: identity-id })
  )
)

(define-read-only (get-emergency-alert (emergency-id uint))
  (map-get? emergency-alerts { emergency-id: emergency-id })
)

(define-read-only (get-alert-response (emergency-id uint) (responder principal))
  (map-get? alert-responses { emergency-id: emergency-id, responder: responder })
)

(define-read-only (is-emergency-active (emergency-id uint))
  (match (map-get? emergency-alerts { emergency-id: emergency-id })
    alert-info (get is-active alert-info)
    false
  )
)

(define-read-only (get-active-emergencies-for-identity (identity-id uint))
  (let
    (
      (total-emergencies (var-get next-emergency-id))
    )
    (fold check-active-emergency (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) { target-id: identity-id, active-count: u0 })
  )
)

(define-private (check-active-emergency (emergency-id uint) (context { target-id: uint, active-count: uint }))
  (match (map-get? emergency-alerts { emergency-id: emergency-id })
    alert-info
      (if (and (is-eq (get identity-id alert-info) (get target-id context)) (get is-active alert-info))
        (merge context { active-count: (+ (get active-count context) u1) })
        context
      )
    context
  )
)

(define-read-only (get-emergency-network-status (identity-id uint))
  (let
    (
      (contacts-data (get-identity-emergency-contacts identity-id))
      (active-emergencies (get-active-emergencies-for-identity identity-id))
    )
    {
      total-contacts: (get total-count contacts-data),
      active-emergencies: (get active-count active-emergencies),
      has-emergency-network: (> (get total-count contacts-data) u0)
    }
  )
)

;; Delegated Data Management Features

(define-public (add-data-delegate (identity-id uint) (delegate principal) (data-key (string-ascii 50)) (duration-blocks uint))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-identity-active identity-id) ERR-IDENTITY-INACTIVE)
    (asserts! (is-none (map-get? data-delegates { identity-id: identity-id, delegate: delegate, data-key: data-key })) ERR-DELEGATE-ALREADY-EXISTS)
    
    (map-set data-delegates
      { identity-id: identity-id, delegate: delegate, data-key: data-key }
      {
        authorized-at: current-block,
        expires-at: (+ current-block duration-blocks)
      }
    )
    (ok true)
  )
)

(define-public (revoke-data-delegate (identity-id uint) (delegate principal) (data-key (string-ascii 50)))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
    )
    (asserts! (is-eq (get owner identity-info) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-delete data-delegates { identity-id: identity-id, delegate: delegate, data-key: data-key })
    (ok true)
  )
)

(define-public (update-identity-data-delegated (identity-id uint) (data-key (string-ascii 50)) (data-value (string-ascii 500)) (encrypted bool))
  (let
    (
      (identity-info (unwrap! (map-get? identities { identity-id: identity-id }) ERR-IDENTITY-NOT-FOUND))
      (delegation-info (unwrap! (map-get? data-delegates { identity-id: identity-id, delegate: tx-sender, data-key: data-key }) ERR-DELEGATE-NOT-FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-identity-active identity-id) ERR-IDENTITY-INACTIVE)
    (asserts! (< current-block (get expires-at delegation-info)) ERR-DELEGATION-EXPIRED)
    
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

(define-read-only (get-data-delegate (identity-id uint) (delegate principal) (data-key (string-ascii 50)))
  (map-get? data-delegates { identity-id: identity-id, delegate: delegate, data-key: data-key })
)

