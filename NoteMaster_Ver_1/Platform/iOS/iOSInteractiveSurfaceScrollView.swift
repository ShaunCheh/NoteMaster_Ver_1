#if os(iOS)
import UIKit

/// A dedicated scroll host for interactive surfaces like fretboard or piano.
/// Touches should reach the child view immediately, but once the gesture becomes
/// a scroll the scroll view must still be able to cancel the child interaction.
final class iOSInteractiveSurfaceScrollView: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureInteractionContract()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureInteractionContract()
    }

    override func touchesShouldBegin(
        _ touches: Set<UITouch>,
        with event: UIEvent?,
        in view: UIView
    ) -> Bool {
        true
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }
}

private extension iOSInteractiveSurfaceScrollView {
    func configureInteractionContract() {
        // Deliver the initial touch immediately to the interactive child view.
        delaysContentTouches = false
        // If the touch turns into a pan, allow the scroll view to take over.
        canCancelContentTouches = true
        panGestureRecognizer.cancelsTouchesInView = true
    }
}
#endif
