//
//  ViewController.swift
//  AR-TestTask
//
//  Created by MacBook on 21.10.2022.
//

import UIKit
import RealityKit
import ARKit
import Combine

class ViewController: UIViewController {

    var imageGotFound = false
    var crystalEntity: Entity? = nil

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
        view.session.delegate = self
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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        downloadImage(url: "https://mix-ar.ru/content/ios/marker.jpg")
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

    private func startTracking(image: CGImage) {
        let arImage = ARReferenceImage(image, orientation: .up, physicalWidth: 0.1)
        arImage.name = "new image"

        guard let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else { return }

        configuration.automaticImageScaleEstimationEnabled = true
        configuration.detectionImages = Set([arImage])
        configuration.maximumNumberOfTrackedImages = 1

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func downloadImage(url: String) {
        guard let url = URL(string: url) else { return }

        getData(from: url) { [weak self] data, response, error in
            guard let data = data,
                  let image = UIImage(data: data)?.cgImage,
                    error == nil else { self?.presentErrorAlert(); return }

            DispatchQueue.main.async {
                self?.startTracking(image: image)
            }
        }
    }

    private func presentErrorAlert() {
        let alert = UIAlertController(title: "Error", message: "Something went wrong", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .cancel) { _ in
            alert.dismiss(animated: true)
        }

        alert.addAction(action)

        present(alert, animated: true)
    }

    private func startPlaneDetection() {
        arView.automaticallyConfigureSession = true
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
    }

    private func addModel(to point: simd_float3) {
        let cube = MeshResource.generateBox(size: 0.05)
        let material = SimpleMaterial(color: UIColor.getRandomColor(), isMetallic: false)
        let entity = ModelEntity(mesh: cube, materials: [material])
        entity.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(world: point)
        anchor.addChild(entity)

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
            guard let entity = anchor.children.first, entity != crystalEntity else { return }
            var transform = entity.transform
            let distanse = Float(0.001) * (crystalEntity == nil ? 1 : 2)
            transform.matrix.columns.3.x += distanse * cos(angle)
            transform.matrix.columns.3.z -= distanse * sin(angle)
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

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let imageAnchors = anchors.compactMap { $0 as? ARImageAnchor }
        guard let anchor = imageAnchors.first, !imageGotFound else { return }

        imageGotFound = true

        var cancellable: AnyCancellable? = nil
        cancellable = ModelEntity.loadModelAsync(named: "crystal_17_2")
            .collect()
            .sink(receiveCompletion: { error in
                print(error)
                cancellable?.cancel()
            }, receiveValue: { [weak self] entities in
                print("loading")
                guard let entity = entities.first else { return }
                let anchorEntity = AnchorEntity(anchor: anchor)
                entity.setScale(SIMD3<Float>(0.001, 0.001, 0.001) , relativeTo: anchorEntity)
                entity.generateCollisionShapes(recursive: true)
                self?.crystalEntity = entity
                anchorEntity.addChild(entity)
                self?.arView.scene.addAnchor(anchorEntity)
            })
    }
}
