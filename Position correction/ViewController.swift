//
//  ViewController.swift
//  Position correction
//
//  Created by Tuan Anh on 8/2/18.
//  Copyright © 2018 UET. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion

class ViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var accText: UILabel!
    @IBOutlet weak var timeCounter: UILabel!
    @IBOutlet weak var headingText: UILabel!
    @IBOutlet weak var xText: UILabel!
    @IBOutlet weak var yText: UILabel!
    @IBOutlet weak var EdistanceText: UILabel!
    @IBOutlet weak var RSSText: UILabel!
    @IBOutlet weak var distanceText: UILabel!
    @IBOutlet weak var correctxText: UILabel!
    @IBOutlet weak var correctyText: UILabel!
    @IBOutlet weak var stepDetect: UILabel!
    
    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()
    
    let x_beacon: Double = 4
    let y_beacon: Double = 4
    
    var verticalAcc: Array<Double> = [0,0]
    var heading: Double = 0
    var x_sensor: Double = 0 //x with no correction
    var y_sensor: Double = 0 //y with no correction
    
    let RSSI_1m:Double = -59.76505
    let n: Double = 1.997007
    var distance: Double = 0 //path loss model distance
    var distance_euclidian: Double = 0
    var x: Double = 0 //Final x with correction
    var y: Double = 0 //Final y with correction
    
    var region = CLBeaconRegion(proximityUUID: UUID(uuidString: "B9407F30-F5F8-466E-AFF9-25556B57FE6D")!, major: 16751, identifier: "d8629e4c77eef8335a4e2f59ec26d737")
    var RSSI:Array<Double> = [0,0,0,0,0,0]
    var filteredRSSI:Double = 0
    
    //Parameters for counting time when standing still
    var seconds = 0
    var timer = Timer()
    var timerIsOn = false
    
    //y = ax + b duong thang noi beacon vs sensor_position
    var a: Double = 0
    var b: Double = 0
    
    //create log files
    let file1 = "no_correction.csv"
    let file2 = "with_correction.csv"
    let dir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    var dataForCSV1 = ""
    var dataForCSV2 = ""
    var file1URL:URL? = nil
    var file2URL:URL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.xText.text = String(x_sensor)
        self.yText.text = String(y_sensor)
        self.correctxText.text = String(x)
        self.correctyText.text = String(y)
        
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingHeading()
        locationManager.startRangingBeacons(in: region)
        updateMotion()
        //startTimer()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.magneticHeading - 91
        self.headingText.text = String(heading)
    }
    
    func startTimer(){
        timerIsOn = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true){ (Timer) in
            self.seconds = self.seconds + 1
            self.timeCounter.text = String(self.seconds)
            if(self.seconds == 10){
               self.correctPosition()
            }
        }
    }
    
    func stopTimer(){
        timer.invalidate()
        seconds = 0
        self.timeCounter.text = String(seconds)
        timerIsOn = false
    }
    
    func correctPosition(){
        if(distance <= 3){
            distance_euclidian = sqrt(pow(x - x_beacon, 2) + pow(y - y_beacon, 2))
            // self.EdistanceText.text = String(distance_euclidian)
            
            a = (y_beacon - y)/(x_beacon - x)
            b = y - a * x
            
            x = (distance * distance - pow(distance_euclidian - distance, 2) - (x_beacon*x_beacon + y_beacon*y_beacon) + (x*x + y*y) - 2*(y - y_beacon) * b) / (2*(x - x_beacon + a*y - a*y_beacon))
            y = a*x + b
            
            correctxText.text = String(x)
            correctyText.text = String(y)
            
            //write data to csv file
            self.dataForCSV2.append("\(self.x),\(self.y)\n")
            self.file2URL = self.dir.appendingPathComponent(self.file2)
            do{
                try self.dataForCSV2.write(to: self.file2URL!, atomically: false, encoding: .utf8)
            }
            catch{
                print("Can't write to file")
            }
        }
        stopTimer()
    }
    
    func updateMotion(){
        motionManager.deviceMotionUpdateInterval = 0.5
        motionManager.showsDeviceMovementDisplay = true
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (Timer) in
            if let accData = self.motionManager.deviceMotion{
                //ACC
                self.accText.text = String(accData.userAcceleration.y)
                self.verticalAcc.removeFirst()
                self.verticalAcc.append(accData.userAcceleration.y)
                
                //STEP DETECTION + UPDATE SENSOR_POSITION
                if ((self.verticalAcc[0] >= 0.06 && self.verticalAcc[1] <= 0.04) || ((self.verticalAcc[0] >= 0.08 && self.verticalAcc[1] <= 0.065))){
                    
                    self.stepDetect.text = "Step detected!"
                    self.stopTimer()
                    
                    self.x_sensor = self.x_sensor + sin(self.heading * (Double.pi/180))
                    self.y_sensor = self.y_sensor + cos(self.heading * (Double.pi/180))
                    self.x = self.x +  sin(self.heading * (Double.pi/180))
                    self.y = self.y +  cos(self.heading * (Double.pi/180))
                    
                    self.xText.text = String(self.x_sensor)
                    self.yText.text = String(self.y_sensor)
                    self.correctxText.text = String(self.x)
                    self.correctyText.text = String(self.y)
                    
                    //write data to csv files
                    self.dataForCSV1.append("\(self.x_sensor),\(self.y_sensor)\n")
                    self.file1URL = self.dir.appendingPathComponent(self.file1)
                    do{
                        try self.dataForCSV1.write(to: self.file1URL!, atomically: false, encoding: .utf8)
                    }
                    catch{
                        print("Can't write to file")
                    }
                    
                    self.dataForCSV2.append("\(self.x),\(self.y)\n")
                    self.file2URL = self.dir.appendingPathComponent(self.file2)
                    do{
                        try self.dataForCSV2.write(to: self.file2URL!, atomically: false, encoding: .utf8)
                    }
                    catch{
                        print("Can't write to file")
                    }
                }
                else{
                    self.stepDetect.text = "Standing still"
                    if(self.timerIsOn == false){
                        self.startTimer()
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        //append new value to RSSI array, compute averaged RSSI
        RSSI.removeFirst()
        RSSI.append(Double(beacons[0].rssi))
        filteredRSSI = averageFilter(inputRSSI: RSSI)
        RSSText.text = String(filteredRSSI)
        
        //compute distance according to path loss model
        distance = pow(10, (RSSI_1m - filteredRSSI)/(10*n))
        distanceText.text = String(distance)
    }
    
    func averageFilter(inputRSSI:Array<Double>) -> Double{
        var averageRSSI:Double = 0
        var sumRSSI:Double = 0
        for i in 0...inputRSSI.count - 1{
            sumRSSI = sumRSSI + inputRSSI[i]
        }
        averageRSSI = sumRSSI/Double(inputRSSI.count)
        
        return averageRSSI
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

