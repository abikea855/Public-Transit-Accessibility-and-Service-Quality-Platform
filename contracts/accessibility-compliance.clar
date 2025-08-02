;; Wheelchair Accessibility Compliance Contract
;; Ensures all transit vehicles and stations accommodate disabled passengers

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))

;; Data Variables
(define-data-var next-report-id uint u1)
(define-data-var total-vehicles uint u0)
(define-data-var compliant-vehicles uint u0)

;; Data Maps
(define-map accessibility-reports
  uint
  {
    vehicle-id: (string-ascii 50),
    station-id: (optional (string-ascii 50)),
    is-compliant: bool,
    accessibility-score: uint,
    inspector: principal,
    timestamp: uint,
    description: (string-ascii 500),
    remediation-required: bool
  }
)

(define-map vehicle-compliance
  (string-ascii 50)
  {
    is-wheelchair-accessible: bool,
    has-priority-seating: bool,
    has-audio-announcements: bool,
    has-visual-displays: bool,
    compliance-score: uint,
    last-inspection: uint,
    violation-count: uint
  }
)

(define-map station-compliance
  (string-ascii 50)
  {
    has-elevator: bool,
    has-ramps: bool,
    has-tactile-guidance: bool,
    has-accessible-restrooms: bool,
    compliance-score: uint,
    last-audit: uint,
    violation-count: uint
  }
)

(define-map authorized-inspectors principal bool)

;; Authorization Functions
(define-public (add-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-inspectors inspector true))
  )
)

(define-public (remove-inspector (inspector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-inspectors inspector))
  )
)

;; Core Functions
(define-public (submit-accessibility-report
  (vehicle-id (string-ascii 50))
  (is-compliant bool)
  (accessibility-score uint)
  (description (string-ascii 500))
)
  (let
    (
      (report-id (var-get next-report-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (default-to false (map-get? authorized-inspectors tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (and (>= accessibility-score u0) (<= accessibility-score u100)) ERR-INVALID-INPUT)
      (asserts! (> (len vehicle-id) u0) ERR-INVALID-INPUT)

      (map-set accessibility-reports report-id
        {
          vehicle-id: vehicle-id,
          station-id: none,
          is-compliant: is-compliant,
          accessibility-score: accessibility-score,
          inspector: tx-sender,
          timestamp: current-time,
          description: description,
          remediation-required: (not is-compliant)
        }
      )

      (var-set next-report-id (+ report-id u1))
      (var-set total-vehicles (+ (var-get total-vehicles) u1))

      (if is-compliant
        (var-set compliant-vehicles (+ (var-get compliant-vehicles) u1))
        true
      )

      (ok report-id)
    )
  )
)

(define-public (update-vehicle-compliance
  (vehicle-id (string-ascii 50))
  (wheelchair-accessible bool)
  (priority-seating bool)
  (audio-announcements bool)
  (visual-displays bool)
)
  (let
    (
      (compliance-score (calculate-vehicle-score wheelchair-accessible priority-seating audio-announcements visual-displays))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (default-to false (map-get? authorized-inspectors tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (> (len vehicle-id) u0) ERR-INVALID-INPUT)

      (map-set vehicle-compliance vehicle-id
        {
          is-wheelchair-accessible: wheelchair-accessible,
          has-priority-seating: priority-seating,
          has-audio-announcements: audio-announcements,
          has-visual-displays: visual-displays,
          compliance-score: compliance-score,
          last-inspection: current-time,
          violation-count: u0
        }
      )

      (ok compliance-score)
    )
  )
)

(define-public (update-station-compliance
  (station-id (string-ascii 50))
  (has-elevator bool)
  (has-ramps bool)
  (tactile-guidance bool)
  (accessible-restrooms bool)
)
  (let
    (
      (compliance-score (calculate-station-score has-elevator has-ramps tactile-guidance accessible-restrooms))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (default-to false (map-get? authorized-inspectors tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (> (len station-id) u0) ERR-INVALID-INPUT)

      (map-set station-compliance station-id
        {
          has-elevator: has-elevator,
          has-ramps: has-ramps,
          has-tactile-guidance: tactile-guidance,
          has-accessible-restrooms: accessible-restrooms,
          compliance-score: compliance-score,
          last-audit: current-time,
          violation-count: u0
        }
      )

      (ok compliance-score)
    )
  )
)

(define-public (report-violation
  (vehicle-id (string-ascii 50))
  (violation-description (string-ascii 500))
)
  (let
    (
      (current-compliance (map-get? vehicle-compliance vehicle-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (is-some current-compliance) ERR-NOT-FOUND)
      (asserts! (> (len violation-description) u0) ERR-INVALID-INPUT)

      (let
        (
          (compliance-data (unwrap-panic current-compliance))
          (new-violation-count (+ (get violation-count compliance-data) u1))
        )
        (map-set vehicle-compliance vehicle-id
          (merge compliance-data { violation-count: new-violation-count })
        )
      )

      (ok true)
    )
  )
)

;; Read-only Functions
(define-read-only (get-accessibility-report (report-id uint))
  (map-get? accessibility-reports report-id)
)

(define-read-only (get-vehicle-compliance (vehicle-id (string-ascii 50)))
  (map-get? vehicle-compliance vehicle-id)
)

(define-read-only (get-station-compliance (station-id (string-ascii 50)))
  (map-get? station-compliance station-id)
)

(define-read-only (get-compliance-rate)
  (let
    (
      (total (var-get total-vehicles))
      (compliant (var-get compliant-vehicles))
    )
    (if (> total u0)
      (/ (* compliant u100) total)
      u0
    )
  )
)

(define-read-only (is-authorized-inspector (inspector principal))
  (default-to false (map-get? authorized-inspectors inspector))
)

;; Private Functions
(define-private (calculate-vehicle-score
  (wheelchair bool)
  (seating bool)
  (audio bool)
  (visual bool)
)
  (let
    (
      (wheelchair-points (if wheelchair u40 u0))
      (seating-points (if seating u25 u0))
      (audio-points (if audio u20 u0))
      (visual-points (if visual u15 u0))
    )
    (+ wheelchair-points seating-points audio-points visual-points)
  )
)

(define-private (calculate-station-score
  (elevator bool)
  (ramps bool)
  (tactile bool)
  (restrooms bool)
)
  (let
    (
      (elevator-points (if elevator u40 u0))
      (ramps-points (if ramps u30 u0))
      (tactile-points (if tactile u20 u0))
      (restrooms-points (if restrooms u10 u0))
    )
    (+ elevator-points ramps-points tactile-points restrooms-points)
  )
)
