//
//  JMOExtension.swift
//  JsonManagedObject
//
//  Created by christophe on 18/06/14.
//  Copyright (c) 2014 cdebortoli. All rights reserved.
//

import Foundation
import CoreData
import JsonManagedObject

extension NSManagedObject {
    /*
    * JSON -> SWIFT
    */
    
    // Set property value
    func setProperty(jmoParameter:JMOConfigModel.JMOParameterModel, fromJson jsonDict:Dictionary<String, AnyObject>) {
        if jsonDict[jmoParameter.jsonKey] != nil {
            if let managedObjectValue : AnyObject = getValue(jmoParameter, fromJsonDictionary: jsonDict) {
                setValue(managedObjectValue, forKey: jmoParameter.attribute)
            }
        }
    }
    
    // Get NSPropertyDescription
    func getPropertyDescription(jmoParameter:JMOConfigModel.JMOParameterModel) -> NSPropertyDescription? {
        if let propertyDescription = self.entity.propertiesByName[jmoParameter.attribute] as? NSPropertyDescription {
            return propertyDescription
        }
        return nil
    }
    
    // Retrieve formated property value from json
    func getValue(jmoParameter:JMOConfigModel.JMOParameterModel, fromJsonDictionary jsonDict:Dictionary<String, AnyObject>) -> AnyObject? {
        
        // Property Description
        var propertyDescriptionOptional = getPropertyDescription(jmoParameter) as NSPropertyDescription?
        
        // Get formated property value
        if let propertyDescription = propertyDescriptionOptional {
            if propertyDescription is NSAttributeDescription {

                if let jsonString = jsonDict[jmoParameter.jsonKey]! as? String {
                    return (propertyDescription as NSAttributeDescription).getAttributeValueForJmoJsonValue(jsonString)
                } else if let jsonNumber = jsonDict[jmoParameter.jsonKey]! as? NSNumber {
                    let jsonString = "\(jsonNumber)"
                    return (propertyDescription as NSAttributeDescription).getAttributeValueForJmoJsonValue(jsonString)
                }
                
            } else if propertyDescription is NSRelationshipDescription {

                if let jsonArray = jsonDict[jmoParameter.jsonKey]! as? Dictionary<String, AnyObject>[] {
                    return (propertyDescription as NSRelationshipDescription).getRelationshipValueForJmoJsonArray(jsonArray)
                } else if let jsonDictRelation = jsonDict[jmoParameter.jsonKey]! as? Dictionary<String, AnyObject> {
                    return jsonManagedObjectSharedInstance.analyzeJsonDictionary(jsonDictRelation, forClass: NSClassFromString((propertyDescription as NSRelationshipDescription).destinationEntity.managedObjectClassName))
                }
                
            }
        }
        return nil
    }
    
    /*
    * SWIFT -> JSON
    */
    func getJmoJson(relationshipClassesToIgnore:String[] = String[]()) -> Dictionary <String, AnyObject>{
        var jsonDict = Dictionary <String, AnyObject>()
        
        var newRelationshipClassesToIgnore = String[]()
        newRelationshipClassesToIgnore += relationshipClassesToIgnore
        newRelationshipClassesToIgnore += NSStringFromClass(self.classForCoder)

        if let configObject = jsonManagedObjectSharedInstance.configDatasource[NSStringFromClass(self.classForCoder)] {
            for parameter in configObject.parameters {
                if let managedObjectValue:AnyObject? = self.valueForKey(parameter.attribute) {
                    
                    if managedObjectValue is NSSet {
                        var relationshipObjects = AnyObject[]()
                        setloop: for objectFromSet:AnyObject in (managedObjectValue as NSSet).allObjects {
                            if (contains(newRelationshipClassesToIgnore, NSStringFromClass(objectFromSet.classForCoder))) {
                                break setloop
                            }
                            relationshipObjects += (objectFromSet as NSManagedObject).getJmoJson(relationshipClassesToIgnore: newRelationshipClassesToIgnore)
                        }
                        if !relationshipObjects.isEmpty {
                            jsonDict[parameter.jsonKey] = relationshipObjects
                        }
                    
                    } else {
                        jsonDict[parameter.jsonKey] = managedObjectValue
                    }
                }
            }
            
            if JMOConfig.jsonWithEnvelope == true {
                return [configObject.classInfo.jsonKey : jsonDict]
            }
        }
        return jsonDict

    }
}

extension NSAttributeDescription {
    func getAttributeValueForJmoJsonValue(jsonValue:String) -> AnyObject? {
        switch(self.attributeType){
        case .DateAttributeType:
            return jsonManagedObjectSharedInstance.dateFormatter.dateFromString(jsonValue)
        case .StringAttributeType:
            return jsonValue
        case .DecimalAttributeType,.DoubleAttributeType:
            return NSNumber.numberWithDouble((jsonValue as NSString).doubleValue)
        case .FloatAttributeType:
            return (jsonValue as NSString).floatValue
        case .Integer16AttributeType,.Integer32AttributeType,.Integer64AttributeType:
            return (jsonValue as NSString).integerValue
        case .BooleanAttributeType:
            return (jsonValue as NSString).boolValue
        default:
            return nil
        }
    }
}

extension NSRelationshipDescription {
    func getRelationshipValueForJmoJsonArray(jsonArray:Dictionary<String, AnyObject>[]) -> NSMutableSet {
        var relationshipSet = NSMutableSet()
        for jsonValue in jsonArray  {
            relationshipSet.addObject(jsonManagedObjectSharedInstance.analyzeJsonDictionary(jsonValue, forClass: NSClassFromString(self.destinationEntity.managedObjectClassName)))
        }
        return relationshipSet
    }
}