//
//  ViewController.swift
//  AR-TestTask
//
//  Created by MacBook on 21.10.2022.
//

import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController {

    var cubesCount = 0 {
        didSet {
            joystickView.isHidden = cubesCount == 0
        }
    }
    
    private lazy var arView: ARView = {
        let view = ARView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(press)
        return view
    }()

    private lazy var joystickView: JoystickView = {
        let view = JoystickView(frame: CGRect.zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.delegate = self
        view.isHidden = true
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupSubviews()
        startPlaneDetection()
        print("loaded")
    }

    override func viewDidLayoutSubviews() {
        arView.frame = view.bounds
    }

    private func setupSubviews() {
        view.addSubview(arView)
        arView.addSubview(joystickView)

        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            joystickView.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            joystickView.bottomAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            joystickView.heightAnchor.constraint(equalToConstant: 100),
            joystickView.widthAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func startPlaneDetection() {
        arView.automaticallyConfigureSession = true
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
    }

    private func addModel(to point: simd_float3) {
        // Creating object
        let cube = MeshResource.generateBox(size: 0.05)
        let material = SimpleMaterial(color: UIColor.getRandomColor(), isMetallic: false)
        let entity = ModelEntity(mesh: cube, materials: [material])
        entity.generateCollisionShapes(recursive: true)

        // Adding object
        let anchor = AnchorEntity(world: point)
        anchor.addChild(entity)

        // Adding anchor to view
        arView.scene.addAnchor(anchor)

        cubesCount += 1
    }

    private func changeColor(_ model: Entity) {
        let model = model as? ModelEntity
        let newMaterials = SimpleMaterial(color: UIColor.getRandomColor(), isMetallic: false)
        model?.model?.materials = [newMaterials]
    }

    private func removeModel(_ model: Entity) {
        guard let anchor = model.anchor else { return }
        arView.scene.removeAnchor(anchor)

        cubesCount -= 1
    }

    @objc
    private func handleTap(_ sender: UITapGestureRecognizer?) {
        guard let tapLocation = sender?.location(in: arView) else { return }

        guard let query = arView.makeRaycastQuery(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal) else { return }

        guard let ray = arView.session.raycast(query).first else { print("Ray"); return }

        let position = simd_make_float3(ray.worldTransform.columns.3)

        if let entity = arView.entity(at: tapLocation) {
            changeColor(entity)
        } else {
            addModel(to: position)
        }
    }

    @objc func handlePress(_ sender: UILongPressGestureRecognizer?) {
        guard let location = sender?.location(in: arView) else { return }

        if let entity = arView.entity(at: location) {
            removeModel(entity)
        } else {
            print("not found")
        }
    }
}

extension ViewController: JoystickViewDelegate {
    func joystickView(joystickView: JoystickView, didMovedTo angle: Float) {
        arView.scene.anchors.forEach { anchor in
            guard let entity = anchor.children.first else { print("no entity"); return }
            var transform = entity.transform
            transform.matrix.columns.3.x += 0.001 * cos(angle)
            transform.matrix.columns.3.z -= 0.001 * sin(angle)
            print(transform)
            entity.move(to: transform, relativeTo: anchor)
        }
    }

    func joystickView(joystickView: JoystickView, didStopedUsing: Bool) {
        arView.scene.anchors.forEach { anchor in
            anchor.children.first?.stopAllAnimations()
        }
    }
}
