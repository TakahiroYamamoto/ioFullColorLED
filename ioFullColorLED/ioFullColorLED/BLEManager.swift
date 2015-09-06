//
//  BLEManager.swift
//  Client
//
//  Created by 山本　恭大 on 2015/02/16.
//  Copyright (c) 2015年 山本　恭大. All rights reserved.
//

import UIKit
import CoreBluetooth

class BLEManager: NSObject,CBCentralManagerDelegate {
    
    var centralManager : CBCentralManager!
    var devices : NSMutableArray = NSMutableArray() // <BLEDevice>
    
    var discoverBlock: (BLEDevice) -> Void = {device in}
    var isScannning : Bool = false
    
    class var sharedInstance : BLEManager {
        struct Static {
            static let instance : BLEManager = BLEManager()
        }
        return Static.instance
    }
    
    override init() {
        super.init()
        
        // serial queueで通信
        centralManager = CBCentralManager(delegate: self, queue: dispatch_queue_create("jp.co.BLEClient", DISPATCH_QUEUE_SERIAL))
    }
    
    // MARK: - API -
    
    /**
    デバイスを探す。終わったらstopScanをセットで呼ぶ
    
    :param: uuid そのuuidのデバイス（ペリフェラル）を探す。空文字を渡すと全てのデバイスをスキャンする
    :return: scanに成功したか
    
    */
    func scanDevices(uuid:NSString) -> Bool
    {
        if centralManager.state == CBCentralManagerState.PoweredOn
        {
            var services :NSArray? = nil
            if(uuid != "")
            {
                services = NSArray(object: CBUUID(string: uuid as String))
                centralManager.scanForPeripheralsWithServices(services as! [AnyObject], options: nil)
            }
            else
            {
                centralManager.scanForPeripheralsWithServices(nil, options: nil)
            }
            isScannning = true
            NSLog("%d",isScannning)
            return true
        }
        println("miss scanDevices")
        return false
    }
    
    /**
    デバイスのスキャンを止める。
    scanDevicesとセットで必ず呼ぶ。
    */
    func stopScan()
    {
        if isScannning == true
        {
            centralManager.stopScan()
            isScannning = false
        }
    }
    
    /*
    ペリフェラルと接続する
    失敗したらnilを返す
    */
    func connect(uuid:NSString) -> BLEDevice?
    {
        let timeOutCount = 30 //3秒でタイムアウト
        if centralManager.state == CBCentralManagerState.PoweredOn
        {
            for device in devices
            {
                // peripheralのservicesか、disccaver時のadvDataからservicesを取得
                var services = (device as! BLEDevice).peripheral.services
                
                if services == nil
                {
                    services = (((device as! BLEDevice) as BLEDevice).serviceUUIDs) as! [AnyObject]
                }
                println("\(services) , \(uuid)")
                if (services as NSArray).containsObject(CBUUID(string: uuid as String))
                {
                    centralManager.connectPeripheral((device as! BLEDevice).peripheral, options: nil)
                    println("connect \(uuid)")
                    var counter = 0
                    while (device as! BLEDevice).state == CBPeripheralState.Disconnected
                    {
                        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
                        if timeOutCount < counter
                        {
                            centralManager.cancelPeripheralConnection((device as! BLEDevice).peripheral)
                            return nil //タイムアウト
                        }
                        counter += 1
                    }
                    return (device as! BLEDevice) // 待った後、state がconnectに変わっていたら、true
                }
            }
        }
        return nil
    }
    
    func disconnect(uuid:NSString) -> Bool
    {
        let timeOutCount = 30 //3秒でタイムアウト
        if centralManager.state == CBCentralManagerState.PoweredOn
        {
            for device in devices
            {
                if var services = (device as! BLEDevice).serviceUUIDs // optional bindingを使っておく
                {
                    if (services as NSArray).containsObject(CBUUID(string: uuid as String))
                    {
                        centralManager.connectPeripheral((device as! BLEDevice).peripheral, options: nil)
                        
                        var counter = 0
                        while (device as! BLEDevice).state == CBPeripheralState.Connected ||
                            (device as! BLEDevice).state == CBPeripheralState.Connecting
                        {
                            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
                            if timeOutCount < counter
                            {
                                centralManager.cancelPeripheralConnection((device as! BLEDevice).peripheral)
                                return false //タイムアウト
                            }
                            counter += 1
                        }
                        return true
                    }
                }
                
            }
        }
        return false
    }
    
    // MARK: - CBCentralManagerDelegate -
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        println("\(central.state.name)")
    }
    
    // scanを始めた後、ペリフェラルが見つかったら呼ばれるdelegate
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        println("didDiscoverPeripheral : \(peripheral)")
        //同じやつがなければ、追加する
        if advertisementData["kCBAdvDataLocalName"] as? NSString != nil
        {
            var newDevice = BLEDevice(peripheral: peripheral, advertismentData: advertisementData, rssi: RSSI)
            var counter : Int = 0
            for device in devices
            {
                if (device as! BLEDevice).identifier == peripheral.identifier.UUIDString
                {
                    // 同じidのが先にいたら、それを消して入れ替える
                    devices.removeObjectAtIndex(counter)
                    break;
                }
                counter += 1
            }
            devices.insertObject(newDevice, atIndex: counter)
            discoverBlock(newDevice)
        }
    }
    
    //disconnect処理が呼ばれたら入ってくるdelegate
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        println("disconnect")
    }
    
    
    // connect処理が呼ばれたら入ってくるdelegate
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        println("connect success")
        for device in devices
        {
            if (device as! BLEDevice).identifier == peripheral.identifier.UUIDString
            {
                if (device as! BLEDevice).peripheral.services == nil
                {
                    (device as! BLEDevice).peripheral.discoverServices(nil) //connectされたら早速serviceを探索する
                }
            }
        }
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!)
    {
        
    }
    
    
}
