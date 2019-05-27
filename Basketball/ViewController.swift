//
//  ViewController.swift
//  Basketball
//
//  Created by Stanislav Teslenko on 5/25/19.
//  Copyright © 2019 Stanislav Teslenko. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    var doneCounter = 0
    var invalidCounter = 0
    var hoopPlaced = false

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set contactDelegate
        sceneView.scene.physicsWorld.contactDelegate = self
        
        // Show statistics such as fps and timing information
 //       sceneView.showsStatistics = true
        
 //       sceneView.debugOptions = [.showPhysicsShapes, .showBoundingBoxes, .showPhysicsFields]
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Allow vertical plane detection
        configuration.planeDetection = [.vertical]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }


    
}

extension ViewController {
    
    func addHoop(at result: ARHitTestResult){
        
        let hoopScene = SCNScene(named: "art.scnassets/Hoop.scn")
        
        guard let hoopNode = hoopScene?.rootNode.childNode(withName: "Hoop", recursively: false) else {return}

        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        hoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoopNode,
                                                                                    options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        // Perfect help: https://www.eecs.wsu.edu/~holder/courses/MAD/slides/12-13-Graphics.pdf
        hoopNode.physicsBody?.categoryBitMask = 0b1111
        hoopNode.physicsBody?.collisionBitMask = 0b1111
        hoopNode.physicsBody?.contactTestBitMask = 0b0000
        
        // Remove all walls
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Wall" {
            node.removeFromParentNode()
            }
        }
   
        // Get circle position
        guard let circleNode = hoopNode.childNode(withName: "circle", recursively: false) else {return}
        let circlePosition = circleNode.position
        
        // Get hoop position
        guard let boxNode = hoopNode.childNode(withName: "box", recursively: false) else {return}
 //       let hoopPosition = boxNode.position
        
        // Add contact 1 to the scene
        let contactUp = createContact()
        contactUp.name = "contactUp"
        hoopNode.addChildNode(contactUp)
        hoopNode.childNode(withName: "contactUp", recursively: false)?.position = SCNVector3(circlePosition.x, circlePosition.y + 0.1, circlePosition.z)
        
        // Add contact 2 to the scene
        let contactDn = createContact()
        contactDn.name = "contactDn"
        hoopNode.addChildNode(contactDn)
        hoopNode.childNode(withName: "contactDn", recursively: false)?.position = SCNVector3(circlePosition.x, circlePosition.y - 0.3, circlePosition.z)
        
        // Add score node
        let score = createScore()
        score.name = "score"
        hoopNode.addChildNode(score)
        hoopNode.childNode(withName: "score", recursively: false)?.position = SCNVector3(circlePosition.x - 0.05, circlePosition.y + 0.5, circlePosition.z)
        
        // Add the hoop to the scene
        sceneView.scene.rootNode.addChildNode(hoopNode)
        hoopPlaced = true
      
    }
    
    func createBasketball() {
        
        guard let frame = sceneView.session.currentFrame else {return}
        
        let ball = SCNNode(geometry: SCNSphere(radius: 0.125))
        ball.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "ball")
        ball.name = "Ball"
        
        let cameraTransform = SCNMatrix4(frame.camera.transform)
        ball.transform = cameraTransform
        
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody = physicsBody
        
        ball.physicsBody?.categoryBitMask = 0b0100
        ball.physicsBody?.collisionBitMask = 0b0100
        ball.physicsBody?.contactTestBitMask = 0b0000
        
        let power = Float(10)
        let x = -cameraTransform.m31 * power
        let y = -cameraTransform.m32 * power
        let z = -cameraTransform.m33 * power
        let force = SCNVector3(x,y,z)
        
        ball.physicsBody?.applyForce(force, asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ball)
    }
    
    func createContact() -> SCNNode {
        
        let plane = SCNNode(geometry: SCNPlane(width: 0.25, height: 0.25))
        plane.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        plane.opacity = 0
        plane.eulerAngles.x = -.pi / 2
        
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: plane))
        plane.physicsBody = body
        plane.physicsBody?.categoryBitMask = 0b0000
        plane.physicsBody?.collisionBitMask = 0b0000
        plane.physicsBody?.contactTestBitMask = 0b0100
        
        return plane
    }
    
    func createScore() -> SCNNode {
        
        let textNode = SCNNode(geometry: SCNText(string: "0", extrusionDepth: 0.1))
        textNode.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        textNode.name = "score"
        textNode.scale = SCNVector3(0.01,0.01,0.01)
        textNode.opacity = 0.7
     
        return textNode
    }
   
}


extension ViewController {
    
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        
        if hoopPlaced {
            
            createBasketball()
            
        } else {
        
        let location = sender.location(in: sceneView)
        guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else {return}
        
        addHoop(at: result)
        }
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else {return}
        guard !hoopPlaced else {return}
        
        let extent = anchor.extent
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.name = "Wall"
        planeNode.opacity = 0.125
        
        node.addChildNode(planeNode)

    }
    
    
}

extension ViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        
        let nodeA = contact.nodeA
        let nameA = nodeA.name
        
        let nodeB = contact.nodeB
        let nameB = nodeB.name
        
        if nameA == "contactUp", nameB == "Ball" {
           nodeB.name = "first"
        }
        
        if nameA == "contactDn", nameB == "first" {
            nodeB.name = "Done"
            
            doneCounter += 1
            print ("Done balls: \(doneCounter)")
            
            let rootNode = nodeA.parent
            guard let scoreText = rootNode?.childNode(withName: "score", recursively: false)?.geometry as? SCNText else {return}
            scoreText.string = String(doneCounter)
            
            
        }
        
        if nameA == "contactDn", nameB != "first" {
            nodeB.name = "Invalid"
            
  //          invalidCounter += 1
  //          print ("Invalid balls: \(invalidCounter)")
        }
        
        
        
        
        
    }
   
    
}
