//
//  Utils.swift
//  airecorder
//
//  Created by BillyPark on 2/13/25.
//

import UIKit

func getDeviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            ptr in String(validatingUTF8: ptr)
        }
    } ?? "unknown"
    
    let modelMap: [String: String] = [
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        
        "iPhone14,5": "iPhone 13",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        
        "iPhone13,2": "iPhone 12",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone8,4": "iPhone SE (1st generation)",
        
        "iPad13,8": "iPad Pro 12.9-inch 5th gen",
        "iPad13,9": "iPad Pro 12.9-inch 5th gen",
        "iPad14,5": "iPad Pro 12.9-inch 6th gen",
        "iPad14,6": "iPad Pro 12.9-inch 6th gen",
        
        "iPad13,4": "iPad Pro 11-inch 3rd gen",
        "iPad13,5": "iPad Pro 11-inch 3rd gen",
        "iPad14,3": "iPad Pro 11-inch 4th gen",
        "iPad14,4": "iPad Pro 11-inch 4th gen",
        
        "iPad13,1": "iPad Air 4th gen",
        "iPad13,2": "iPad Air 4th gen",
        "iPad13,16": "iPad Air 5th gen",
        "iPad13,17": "iPad Air 5th gen",
        
        "iPad14,1": "iPad mini 6th gen",
        "iPad14,2": "iPad mini 6th gen",
        
        "iPad13,18": "iPad 10th gen",
        "iPad13,19": "iPad 10th gen",
        "iPad12,1": "iPad 9th gen",
        "iPad12,2": "iPad 9th gen",
        
        "i386": "Simulator",
        "x86_64": "Simulator",
        "arm64": "Simulator"
    ]
    
    return modelMap[modelCode] ?? modelCode
}

func isLowerThaniPhone14() -> Bool {
    let deviceModel = getDeviceModel()
    
    let newerModels = [
        "iPhone 15", "iPhone 15 Plus", "iPhone 15 Pro", "iPhone 15 Pro Max",
        "iPhone 14", "iPhone 14 Plus", "iPhone 14 Pro", "iPhone 14 Pro Max",
        
        "iPad Pro 12.9-inch 5th gen", "iPad Pro 12.9-inch 6th gen",
        "iPad Pro 11-inch 3rd gen", "iPad Pro 11-inch 4th gen",
        "iPad Air 5th gen"
    ]
    
    return !newerModels.contains(deviceModel)
}
