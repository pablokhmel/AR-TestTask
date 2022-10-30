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

    // MARK: - Properties

    var coinPicked: AVAudioPlayer?

    var imageGotFound = false
    var crystalEntity: Entity? = nil
    var coinsModels: [Entity] = [] {
        didSet {
            if oldValue.count != 0 && coinsModels.count == 0 && cubesEntities.count != 0 {
                addCoins(count: 3)
            }
        }
    }

    var cubesEntities: [Entity] = [] {
        didSet {
            joystickView.isHidden = cubesEntities.count == 0
            if oldValue.count == 0 && cubesEntities.count != 0 {
                addCoins(count: 3)
            }

            if oldValue.count != 0 && cubesEntities.count == 0 {
                removeAllCoins()
            }
        }
    }

    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }

    var subscriptions: [Cancellable] = []

    var cubesCount = 0 {
        didSet {
            joystickView.isHidden = cubesCount == 0
            addCoins(count: 3)
        }
    }

    // MARK: - Views

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

    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.text = "Score: \(score)"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = .white
        label.textColor = .gray
        return label
    }()

    // MARK: - LifeCycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSubviews()
        startPlaneDetection()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        downloadImage(url: "https://mix-ar.ru/content/ios/marker.jpg")
    }

    // MARK: View's methods

    private func setupSubviews() {
        view.addSubview(arView)
        arView.addSubview(joystickView)
        arView.addSubview(scoreLabel)

        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            joystickView.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            joystickView.bottomAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            joystickView.heightAnchor.constraint(equalToConstant: 100),
            joystickView.widthAnchor.constraint(equalToConstant: 100),

            scoreLabel.leadingAnchor.constraint(equalTo: arView.leadingAnchor, constant: 30),
            scoreLabel.topAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.topAnchor, constant: 30)
        ])
    }

    // MARK: Scene Configuration

    private func startTracking(image: CGImage) {
        let arImage = ARReferenceImage(image, orientation: .up, physicalWidth: 0.1)
        arImage.name = "new image"

        guard let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else { return }

        configuration.automaticImageScaleEstimationEnabled = true
        configuration.detectionImages = Set([arImage])
        configuration.maximumNumberOfTrackedImages = 1

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }


    private func startPlaneDetection() {
        arView.automaticallyConfigureSession = true
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
    }

    // MARK: - Network methods

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

    // MARK: - Cubes methods

    private func addModel(to point: simd_float3) {
        print(point)
        let cube = MeshResource.generateBox(size: 0.05)
        let material = SimpleMaterial(color: UIColor.getRandomColor(), isMetallic: false)
        let entity = ModelEntity(mesh: cube, materials: [material])
        entity.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(world: point)
        anchor.addChild(entity)

        arView.scene.addAnchor(anchor)

        cubesEntities.append(entity)
    }

    private func changeColor(_ model: Entity) {
        let model = model as? ModelEntity
        let newMaterials = SimpleMaterial(color: UIColor.getRandomColor(), isMetallic: false)
        model?.model?.materials = [newMaterials]
    }

    private func removeModel(_ model: Entity) {
        guard let anchor = model.anchor else { return }
        arView.scene.removeAnchor(anchor)
        cubesEntities.removeAll(where: { $0 == model })
    }

    private func getRandomsElement() -> Entity {
        return cubesEntities.randomElement() ?? Entity()
    }

    // MARK: - Coin methods

    private func addCoins(count: Int) {
        for _ in 0..<count {
            var cancellable: AnyCancellable? = nil
            cancellable = ModelEntity.loadModelAsync(named: "coin")
                .collect()
                .sink(receiveCompletion: { error in
                    print(error)
                    cancellable?.cancel()
                }, receiveValue: { [weak self] entities in
                    print("loading")
                    guard let entity = entities.first else { return }
                    self?.append(coin: entity)
                })
        }
    }

    private func append(coin: Entity) {
        let randomEntity = getRandomsElement()
        guard var entitiesPos = randomEntity.anchor?.position(relativeTo: nil) else { return }
        entitiesPos.x += [Float.random(in: -0.15...(-0.05)), Float.random(in: 0.05...0.15)].randomElement()!
        entitiesPos.z += [Float.random(in: -0.15...(-0.05)), Float.random(in: 0.05...0.15)].randomElement()!
        let anchor = AnchorEntity(world: entitiesPos)
        anchor.addChild(coin)
        coin.setScale(SIMD3<Float>(0.0005, 0.0005, 0.0005), relativeTo: nil)
        coin.generateCollisionShapes(recursive: true)
        let sub = arView.scene.subscribe(to: CollisionEvents.Began.self, on: coin) { [weak self] event in
            self?.collised(coin: coin, event: event)
        }

        subscriptions += [sub]

        coinsModels.append(coin)
        arView.scene.addAnchor(anchor)
    }

    private func removeAllCoins() {
        coinsModels.forEach { coin in
            guard let anchor = coin.anchor else { return }
            arView.scene.removeAnchor(anchor)
        }

        coinsModels = []
    }

    private func collised(coin: Entity, event: CollisionEvents.Began) {
        // Checking
        guard (cubesEntities.contains(event.entityA) && coinsModels.contains(event.entityB)) ||
                (cubesEntities.contains(event.entityB) && coinsModels.contains(event.entityA)) else { return }
        guard let anchor = coin.anchor else { return }

        // Removing entity
        DispatchQueue.main.async {
            self.arView.scene.removeAnchor(anchor)
        }

        coinsModels.removeAll(where: { $0 == coin })

        // Adding score
        score += 1

        // Play sound
        playCoinSound()
    }

    private func playCoinSound() {
        guard let path = Bundle.main.path(forResource: "coin_sound.mp3", ofType: nil) else { return }
        let url = URL(fileURLWithPath: path)

        do {
            coinPicked = try AVAudioPlayer(contentsOf: url)
            coinPicked?.play()
        } catch {
            print(error)
        }
    }

    // MARK: - Objc methods

    @objc
    private func handleTap(_ sender: UITapGestureRecognizer?) {
        guard let tapLocation = sender?.location(in: arView) else { return }

        guard let query = arView.makeRaycastQuery(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal) else { return }

        guard let ray = arView.session.raycast(query).first else { print("Ray"); return }

        let position = simd_make_float3(ray.worldTransform.columns.3)

        if let entity = arView.entity(at: tapLocation) {
            guard cubesEntities.contains(where: { $0 == entity }) else { return }
            changeColor(entity)
        } else {
            addModel(to: position)
        }
    }

    @objc func handlePress(_ sender: UILongPressGestureRecognizer?) {
        guard let location = sender?.location(in: arView) else { return }

        if let entity = arView.entity(at: location) {
            guard cubesEntities.contains(where: { $0 == entity }) else { return }
            removeModel(entity)
        } else {
            print("not found")
        }
    }
}

// MARK: - Protocol: Joystick View

extension ViewController: JoystickViewDelegate {
    func joystickView(joystickView: JoystickView, didMovedTo angle: Float) {
        cubesEntities.forEach { entity in
            var transform = entity.transform
            let distanse = Float(0.001) * (crystalEntity == nil ? 1 : 2)
            transform.matrix.columns.3.x += distanse * cos(angle)
            transform.matrix.columns.3.z -= distanse * sin(angle)
            entity.move(to: transform, relativeTo: entity.anchor)
        }
    }
}

// MARK: - Protocol: ARSession

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
