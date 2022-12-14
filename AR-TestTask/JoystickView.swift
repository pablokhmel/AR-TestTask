//
//  JoystickView.swift
//  AR-TestTask
//
//  Created by MacBook on 25.10.2022.
//

import UIKit

// MARK: - Protocols

protocol JoystickViewDelegate {
    func joystickView(joystickView: JoystickView, didMovedTo angle: Float)
}

extension JoystickViewDelegate {
    func joystickView(joystickView: JoystickView, didMovedTo angle: Float) {}
}

class JoystickView: UIView {

    // MARK: - Properties

    var delegate: JoystickViewDelegate?

    var timer: Timer?

    // MARK: - Views

    private lazy var circleView: UIView = {
        let view = UIView()
        view.center = center
        view.layer.cornerRadius = 20
        view.backgroundColor = .cyan
        return view
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Views methods

    override func layoutSubviews() {
        layer.cornerRadius = frame.height / 2
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 5

        joystickMovedTo()
    }

    private func commonInit() {
        addSubview(circleView)
    }

    // MARK: - Timer methods

    private func fireTimer(angle: Float? = nil) {
        timer?.invalidate()
        timer = nil

        guard let angle = angle else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.delegate?.joystickView(joystickView: self ?? JoystickView(), didMovedTo: angle)
        }
        timer?.fire()
    }

    // MARK: - Movement methods

    private func joystickMovedTo(point: CGPoint? = nil) {
        guard let point = point else {
            circleView.frame = CGRect(origin: CGPoint(x: frame.width / 2 - 20, y: frame.height / 2 - 20),
                                      size: CGSize(width: 40, height: 40))
            fireTimer()

            return
        }

        let x = point.x - frame.width / 2
        let y = point.y - frame.height / 2

        guard x != 0 else { return }

        let newX = x / sqrt(x * x + y * y)
        let newY = y / sqrt(x * x + y * y)

        let angleTan = newY / newX
        var angle =  atan(angleTan)

        if x <= 0 {
            angle += Double.pi
        }

        let sendAngle: CGFloat

        if x >= 0 && y <= 0 {
            sendAngle = -angle
        } else {
            sendAngle = 2 * Double.pi - angle
        }

        fireTimer(angle: Float(sendAngle))

        if sqrt(x * x + y * y) > frame.width / 2 {
            let x = frame.width / 2 * (1 + cos(angle)) - 20
            let y = frame.height / 2 * (1 + sin(angle)) - 20
            let newPosition = CGRect(x: x,
                                     y: y,
                                     width: 40,
                                     height: 40)

            circleView.frame = newPosition
        } else {
            circleView.frame = CGRect(origin: CGPoint(x: point.x - 20, y: point.y - 20),
                                      size: CGSize(width: 40, height: 40))
        }
    }

    // MARK: - Overriding touches methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        joystickMovedTo(point: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        joystickMovedTo(point: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        joystickMovedTo()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        joystickMovedTo()
    }
}
