//
//  JsonManagedObject.swift
//  JsonManagedObject-Swift
//
//  Created by christophe on 08/06/14.
//  Copyright (c) 2014 cdebortoli. All rights reserved.
//

import Foundation

public let jsonManagedObjectSharedInstance = JsonManagedObject()

public class JsonManagedObject {
    public let dateFormatter = NSDateFormatter()
    internal lazy var configDatasource = JMOConfigDatasource() // Data from the template file
    
    public init() {
        dateFormatter.dateFormat = JMOConfig.dateFormat
    }
    
    // Analyze an array of Dictionary
    public func analyzeJsonArray(jsonArray:[AnyObject], forClass objectClass:AnyClass) -> [AnyObject] {
        var resultArray = [AnyObject]()
        for jsonArrayOccurence:AnyObject in jsonArray {
            if let jsonDict = jsonArrayOccurence as? [String: AnyObject] {
                if let objectFromJson : AnyObject = analyzeJsonDictionary(jsonDict, forClass: objectClass) {
                    resultArray.append(objectFromJson)
                }
            }
        }
        return resultArray
    }
    
    // Analyze a dictionary
    public func analyzeJsonDictionary(jsonDictionary:[String: AnyObject], forClass objectClass:AnyClass) -> AnyObject? {
        // 1 - Find the config object for the specified class
        if let configObject = configDatasource[NSStringFromClass(objectClass)] {
            
            // 2 - Json Dictionary
            var jsonFormatedDictionary = jsonDictionary
            // Envelope
            if JMOConfig.jsonWithEnvelope {
                if let dictUnwrapped = jsonDictionary[configObject.classInfo.jsonKey]! as? [String: AnyObject] {
                    jsonFormatedDictionary = dictUnwrapped
                }
            }
            
            // 3a - NSManagedObject Parse & init
            if class_getSuperclass(objectClass) is NSManagedObject.Type {
                if JMOConfig.managedObjectContext == nil {
                    return nil
                }
                
                var managedObject:NSManagedObject
                if JMOConfig.temporaryNSManagedObjectInstance == false {
                    managedObject = NSEntityDescription.insertNewObjectForEntityForName(NSStringFromClass(objectClass), inManagedObjectContext: JMOConfig.managedObjectContext!) as NSManagedObject
                    for parameter in configObject.parameters {
                        managedObject.setProperty(parameter, fromJson: jsonFormatedDictionary)
                    }
                    return managedObject
                } else {
                    let entityDescriptionOptional = NSEntityDescription.entityForName(NSStringFromClass(objectClass), inManagedObjectContext: JMOConfig.managedObjectContext!)
                    if let entityDescription = entityDescriptionOptional {
                        managedObject = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil)
                        for parameter in configObject.parameters {
                            managedObject.setProperty(parameter, fromJson: jsonFormatedDictionary)
                        }
                        return managedObject
                    }
                }
            // 3b - CustomObject Parse & init
            } else if class_getSuperclass(objectClass) is JMOWrapper.Type {
                var classType: NSObject.Type = objectClass as NSObject.Type
                var cobject : AnyObject! = classType()
                (cobject as JMOWrapper).childrenClassReference = objectClass
                
                for parameter in configObject.parameters {
                    (cobject as JMOWrapper).setParameter(parameter, fromJson: jsonFormatedDictionary)
                }
                return cobject
            }
        }
        return nil
    }
}
