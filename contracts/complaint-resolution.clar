;; Customer Complaint Resolution Contract
;; Manages and responds to passenger concerns and suggestions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-RESOLVED (err u409))

;; Data Variables
(define-data-var next-complaint-id uint u1)
(define-data-var total-complaints uint u0)
(define-data-var resolved-complaints uint u0)

;; Data Maps
(define-map complaints
  uint
  {
    complainant: principal,
    category: (string-ascii 50),
    priority: uint,
    description: (string-ascii 500),
    route-id: (optional (string-ascii 50)),
    vehicle-id: (optional (string-ascii 50)),
    station-id: (optional (string-ascii 50)),
    timestamp: uint,
    status: (string-ascii 20),
    assigned-to: (optional principal),
    resolution: (optional (string-ascii 500)),
    resolution-time: (optional uint),
    satisfaction-rating: (optional uint)
  }
)

(define-map complaint-categories
  (string-ascii 50)
  {
    category-name: (string-ascii 100),
    target-resolution-time: uint,
    escalation-threshold: uint,
    complaint-count: uint,
    average-resolution-time: uint,
    satisfaction-score: uint
  }
)

(define-map resolution-staff
  principal
  {
    staff-name: (string-ascii 100),
    department: (string-ascii 50),
    assigned-complaints: uint,
    resolved-complaints: uint,
    average-resolution-time: uint,
    satisfaction-rating: uint,
    is-active: bool
  }
)

(define-map complaint-responses
  { complaint-id: uint, response-id: uint }
  {
    responder: principal,
    response-text: (string-ascii 500),
    response-timestamp: uint,
    is-public: bool
  }
)

(define-map authorized-staff principal bool)

;; Authorization Functions
(define-public (add-staff-member (staff principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-staff staff true))
  )
)

(define-public (remove-staff-member (staff principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-staff staff))
  )
)

;; Core Functions
(define-public (submit-complaint
  (category (string-ascii 50))
  (priority uint)
  (description (string-ascii 500))
  (route-id (optional (string-ascii 50)))
  (vehicle-id (optional (string-ascii 50)))
  (station-id (optional (string-ascii 50)))
)
  (let
    (
      (complaint-id (var-get next-complaint-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (> (len category) u0) ERR-INVALID-INPUT)
      (asserts! (> (len description) u0) ERR-INVALID-INPUT)
      (asserts! (and (>= priority u1) (<= priority u5)) ERR-INVALID-INPUT)

      (map-set complaints complaint-id
        {
          complainant: tx-sender,
          category: category,
          priority: priority,
          description: description,
          route-id: route-id,
          vehicle-id: vehicle-id,
          station-id: station-id,
          timestamp: current-time,
          status: "submitted",
          assigned-to: none,
          resolution: none,
          resolution-time: none,
          satisfaction-rating: none
        }
      )

      (var-set next-complaint-id (+ complaint-id u1))
      (var-set total-complaints (+ (var-get total-complaints) u1))

      ;; Update category statistics
      (update-category-stats category)

      (ok complaint-id)
    )
  )
)

(define-public (assign-complaint
  (complaint-id uint)
  (staff-member principal)
)
  (let
    (
      (complaint (map-get? complaints complaint-id))
    )
    (begin
      (asserts! (default-to false (map-get? authorized-staff tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (is-some complaint) ERR-NOT-FOUND)

      (let
        (
          (complaint-data (unwrap-panic complaint))
        )
        (asserts! (is-eq (get status complaint-data) "submitted") ERR-INVALID-INPUT)

        (map-set complaints complaint-id
          (merge complaint-data
            {
              status: "assigned",
              assigned-to: (some staff-member)
            }
          )
        )

        ;; Update staff assignment count
        (update-staff-assignment staff-member)
      )

      (ok true)
    )
  )
)

(define-public (resolve-complaint
  (complaint-id uint)
  (resolution-text (string-ascii 500))
)
  (let
    (
      (complaint (map-get? complaints complaint-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (default-to false (map-get? authorized-staff tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (is-some complaint) ERR-NOT-FOUND)
      (asserts! (> (len resolution-text) u0) ERR-INVALID-INPUT)

      (let
        (
          (complaint-data (unwrap-panic complaint))
        )
        (asserts! (not (is-eq (get status complaint-data) "resolved")) ERR-ALREADY-RESOLVED)

        (map-set complaints complaint-id
          (merge complaint-data
            {
              status: "resolved",
              resolution: (some resolution-text),
              resolution-time: (some current-time)
            }
          )
        )

        (var-set resolved-complaints (+ (var-get resolved-complaints) u1))

        ;; Update staff resolution count
        (if (is-some (get assigned-to complaint-data))
          (update-staff-resolution (unwrap-panic (get assigned-to complaint-data)))
          true
        )
      )

      (ok true)
    )
  )
)

(define-public (add-complaint-response
  (complaint-id uint)
  (response-id uint)
  (response-text (string-ascii 500))
  (is-public bool)
)
  (let
    (
      (complaint (map-get? complaints complaint-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (default-to false (map-get? authorized-staff tx-sender)) ERR-NOT-AUTHORIZED)
      (asserts! (is-some complaint) ERR-NOT-FOUND)
      (asserts! (> (len response-text) u0) ERR-INVALID-INPUT)

      (map-set complaint-responses { complaint-id: complaint-id, response-id: response-id }
        {
          responder: tx-sender,
          response-text: response-text,
          response-timestamp: current-time,
          is-public: is-public
        }
      )

      (ok true)
    )
  )
)

(define-public (rate-resolution
  (complaint-id uint)
  (satisfaction-rating uint)
)
  (let
    (
      (complaint (map-get? complaints complaint-id))
    )
    (begin
      (asserts! (is-some complaint) ERR-NOT-FOUND)
      (asserts! (and (>= satisfaction-rating u1) (<= satisfaction-rating u5)) ERR-INVALID-INPUT)

      (let
        (
          (complaint-data (unwrap-panic complaint))
        )
        (asserts! (is-eq tx-sender (get complainant complaint-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status complaint-data) "resolved") ERR-INVALID-INPUT)

        (map-set complaints complaint-id
          (merge complaint-data { satisfaction-rating: (some satisfaction-rating) })
        )
      )

      (ok true)
    )
  )
)

(define-public (setup-complaint-category
  (category-id (string-ascii 50))
  (category-name (string-ascii 100))
  (target-resolution-time uint)
  (escalation-threshold uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len category-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len category-name) u0) ERR-INVALID-INPUT)
    (asserts! (> target-resolution-time u0) ERR-INVALID-INPUT)

    (map-set complaint-categories category-id
      {
        category-name: category-name,
        target-resolution-time: target-resolution-time,
        escalation-threshold: escalation-threshold,
        complaint-count: u0,
        average-resolution-time: u0,
        satisfaction-score: u0
      }
    )

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-complaint (complaint-id uint))
  (map-get? complaints complaint-id)
)

(define-read-only (get-complaint-category (category-id (string-ascii 50)))
  (map-get? complaint-categories category-id)
)

(define-read-only (get-staff-member (staff principal))
  (map-get? resolution-staff staff)
)

(define-read-only (get-complaint-response (complaint-id uint) (response-id uint))
  (map-get? complaint-responses { complaint-id: complaint-id, response-id: response-id })
)

(define-read-only (get-resolution-rate)
  (let
    (
      (total (var-get total-complaints))
      (resolved (var-get resolved-complaints))
    )
    (if (> total u0)
      (/ (* resolved u100) total)
      u0
    )
  )
)

(define-read-only (is-authorized-staff (staff principal))
  (default-to false (map-get? authorized-staff staff))
)

;; Private Functions
(define-private (update-category-stats (category (string-ascii 50)))
  (let
    (
      (current-stats (map-get? complaint-categories category))
    )
    (if (is-some current-stats)
      (let
        (
          (stats (unwrap-panic current-stats))
          (new-count (+ (get complaint-count stats) u1))
        )
        (map-set complaint-categories category
          (merge stats { complaint-count: new-count })
        )
      )
      true
    )
  )
)

(define-private (update-staff-assignment (staff principal))
  (let
    (
      (current-staff (map-get? resolution-staff staff))
    )
    (if (is-some current-staff)
      (let
        (
          (staff-data (unwrap-panic current-staff))
          (new-assigned (+ (get assigned-complaints staff-data) u1))
        )
        (map-set resolution-staff staff
          (merge staff-data { assigned-complaints: new-assigned })
        )
      )
      true
    )
  )
)

(define-private (update-staff-resolution (staff principal))
  (let
    (
      (current-staff (map-get? resolution-staff staff))
    )
    (if (is-some current-staff)
      (let
        (
          (staff-data (unwrap-panic current-staff))
          (new-resolved (+ (get resolved-complaints staff-data) u1))
        )
        (map-set resolution-staff staff
          (merge staff-data { resolved-complaints: new-resolved })
        )
      )
      true
    )
  )
)
