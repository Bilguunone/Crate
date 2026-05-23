//
//  PreviewGestureLayer.swift
//  Crate
//
//  Created by Crate Contributors on 2026-05-23.
//

import AppKit
import SwiftUI

struct PreviewGestureLayer: NSViewRepresentable {
    var onPan: (CGSize) -> Void
    var onMagnify: (CGFloat) -> Void
    var onRotate: (CGFloat) -> Void
    var onReset: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPan: onPan,
            onMagnify: onMagnify,
            onRotate: onRotate,
            onReset: onReset
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = PreviewGestureNSView()

        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let magnify = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        let rotate = NSRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotate(_:)))
        let doubleClick = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClick.numberOfClicksRequired = 2

        [pan, magnify, rotate, doubleClick].forEach { recognizer in
            recognizer.delegate = context.coordinator
            view.addGestureRecognizer(recognizer)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onPan = onPan
        context.coordinator.onMagnify = onMagnify
        context.coordinator.onRotate = onRotate
        context.coordinator.onReset = onReset
    }

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var onPan: (CGSize) -> Void
        var onMagnify: (CGFloat) -> Void
        var onRotate: (CGFloat) -> Void
        var onReset: () -> Void

        init(
            onPan: @escaping (CGSize) -> Void,
            onMagnify: @escaping (CGFloat) -> Void,
            onRotate: @escaping (CGFloat) -> Void,
            onReset: @escaping () -> Void
        ) {
            self.onPan = onPan
            self.onMagnify = onMagnify
            self.onRotate = onRotate
            self.onReset = onReset
        }

        @MainActor
        @objc func handlePan(_ recognizer: NSPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            guard translation != .zero else { return }
            onPan(CGSize(width: translation.x, height: translation.y))
            recognizer.setTranslation(.zero, in: view)
        }

        @MainActor
        @objc func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
            guard recognizer.magnification != 0 else { return }
            onMagnify(recognizer.magnification)
            recognizer.magnification = 0
        }

        @MainActor
        @objc func handleRotate(_ recognizer: NSRotationGestureRecognizer) {
            guard recognizer.rotationInDegrees != 0 else { return }
            onRotate(-recognizer.rotationInDegrees)
            recognizer.rotationInDegrees = 0
        }

        @MainActor
        @objc func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
            if recognizer.state == .ended {
                onReset()
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: NSGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private final class PreviewGestureNSView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
