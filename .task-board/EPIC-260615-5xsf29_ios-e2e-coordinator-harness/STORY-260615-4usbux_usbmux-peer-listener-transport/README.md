# STORY-260615-4usbux: usbmux-peer-listener-transport

## Description
Add a project-neutral USB transport mode for physical iOS E2E tests where each UI test peer starts a device-side listener and the Mac runner connects to it through `iproxy`.

## Scope
Reusable toolkit transport only: UITestKit peer listener transport, Mac runner connection registry, `iproxy` launch planning, config/env contract, sample proof, and Tap2Cash consumer validation. Do not add product-specific Tap2Cash semantics and do not remove the existing WebSocket coordinator path.

## Acceptance Criteria
The toolkit supports a usbmux peer-listener mode where peers wait for the harness connection, the Mac runner connects to each peer through `iproxy`, events and publish receipts use the existing JSON protocol, and a sample smoke proves the concept before Tap2Cash-specific validation.
