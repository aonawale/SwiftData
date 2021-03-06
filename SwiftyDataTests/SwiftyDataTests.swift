//
//  SwiftyDataTests.swift
//  SwiftyDataTests
//
//  Created by Ahmed Onawale on 6/28/16.
//  Copyright © 2016 Ahmed Onawale. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice,
//  this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
//  THE POSSIBILITY OF SUCH DAMAGE.
//

import XCTest
import CoreData
@testable import SwiftyData

class Person: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var age: Int64
}

extension Person: KeyCodeable {
    enum Key: String {
        case name
        case age
    }
}

class Employee: Person {
    @NSManaged var employmentDate: NSDate
    @NSManaged var department: Department?
}

extension Employee {
    enum Key: String {
        case name, age, employmentDate, department
    }
}

class Department: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var employees: [Employee]
}

extension Department: KeyCodeable {
    enum Key: String {
        case name, employees
    }
    
    override class var entityName: String {
        return "Organization"
    }
}

class SwiftyDataTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SwiftyData.sharedData.bundle = NSBundle(forClass: self.dynamicType)
        SwiftyData.sharedData.logLevel = .None
    }
    
    override func tearDown() {
        super.tearDown()
        Person.destroyAll()
        Department.destroyAll()
        Employee.destroyAll()
    }
    
    func testRelationshipCascadeDeleteRule() {
        let employees = (1...50).map { Employee.create([.employmentDate: NSDate(timeIntervalSinceNow: NSTimeInterval($0))]) }
        let department = Department.create([.name: "Health", .employees: employees])
        XCTAssertEqual(department.employees.count, 50)
        department.destroy()
        department.save()
        department.employees.forEach { XCTAssertTrue($0.deleted) }
    }
    
    func testRelationshipInverses() {
        let employee = Employee.create([.employmentDate: NSDate()])
        let department = Department.create([.name: "Accounting", .employees: []])
        XCTAssertTrue(department.employees.isEmpty)
        XCTAssertNil(employee.department)
        
        employee.department = department
        XCTAssertFalse(department.employees.isEmpty)
        XCTAssertTrue(department.employees.contains(employee))
        XCTAssertEqual(employee.department, department)
        
        employee.destroy()
        employee.save()
        XCTAssertTrue(department.employees.isEmpty)
    }
    
    func testRelationship() {
        let employees = (1...20).map { Employee.create([.employmentDate: NSDate(timeIntervalSinceNow: NSTimeInterval($0))]) }
        // if toMany relationship is `ordered`, the type must be an Array, else it must be a Set
        // like so: var employees: Set<Employee> and must be set like this:
        // Set(arrayLiteral: employee)
        let department = Department.create([.name: "Accounting", .employees: employees])
        XCTAssertEqual(department.employees.count, 20)
        employees.forEach {
            XCTAssertTrue(department.employees.contains($0))
            XCTAssertEqual($0.department, department)
        }
        XCTAssertEqual(department.employees.count, Employee.find(where: "department == %@", arguments: department).count)
    }
    
    func testCreateEmptyObject() {
        let person = Person.create()
        XCTAssertTrue(person.inserted)
        XCTAssertNotNil(person)
        XCTAssertEqual(person.name, "")
        XCTAssertEqual(person.age, 0)
    }
    
    func testUpdateObject() {
        let person = Person.create()
        person.set([.name: "Ahmed", .age: 18])
        XCTAssertTrue(person.hasChanges)
        XCTAssertEqual(person.name, "Ahmed")
        XCTAssertEqual(person.age, 18)
    }

    func testCreateObjectWithProperties() {
        let person = Person.create([.name: "Onawale", .age: 20])
        XCTAssertTrue(person.inserted)
        XCTAssertEqual(person.name, "Onawale")
        XCTAssertEqual(person.age, 20)
        let prop = person.get([.name, .age])
        XCTAssertEqual(prop["name"] as? String, "Onawale")
        XCTAssertEqual(prop["age"] as? Int, 20)
    }
    
    func testFindAllObjects() {
        _ = Person.create([.name: "Ahmed", .age: 10])
        _ = Person.create([.name: "Onawale", .age: 28])
        _ = Person.create([.name: "Ayo", .age: 40])
        let people = Person.findAll()
        XCTAssertEqual(people.count, 3)
    }
    
    func testFindObjectById() {
        let id = Person.create([.name: "Ahmed", .age: 29]).objectID
        let person = Person.findById(id)
        XCTAssertNotNil(person)
        XCTAssertEqual(person?.name, "Ahmed")
        XCTAssertEqual(person?.age, 29)
    }
    
    func testFindObjectByNSURL() {
        let url = Person.create([.name: "Ahmed", .age: 29]).objectID.URIRepresentation()
        let person = Person.findByNSURL(url)
        XCTAssertNotNil(person)
        XCTAssertEqual(person?.name, "Ahmed")
        XCTAssertEqual(person?.age, 29)
    }
    
    func testDestroyObject() {
        let person = Person.create()
        XCTAssertNotNil(person)
        person.destroy()
        XCTAssertTrue(person.deleted)
        XCTAssertNil(Person.findById(person.objectID))
    }
    
    func testDestroyAllObjects() {
        _ = Person.create([.name: "Ahmed", .age: 10])
        _ = Person.create([.name: "Onawale", .age: 28])
        _ = Person.create([.name: "Ayo", .age: 40])
        XCTAssertEqual(Person.findAll().count, 3)
        Person.destroyAll()
        XCTAssertEqual(Person.findAll().count, 0)
    }
    
    func testSaveContext() {
        XCTAssertFalse(Person.save())
        let person = Person.create([.name: "Ahmed", .age: 33])
        XCTAssertTrue(person.save())
        XCTAssertFalse(person.save())
        person.set([.name: "Onawale"])
        XCTAssertTrue(Person.save())
    }
    
    func testBulkCreationOfObjects() {
        let people = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        XCTAssertEqual(people.count, 3)
    }
    
    func testReloadObject() {
        let person = Person.create([.name: "Ahmed", .age: 33])
        XCTAssertTrue(person.save())
        person.set([.name: "Onawale", .age: 40])
        XCTAssertEqual(person.name, "Onawale")
        XCTAssertEqual(person.age, 40)
        person.reload()
        XCTAssertNotEqual(person.name, "Onawale")
        XCTAssertNotEqual(person.age, 40)
        XCTAssertEqual(person.name, "Ahmed")
        XCTAssertEqual(person.age, 33)
    }
    
    func testQueryObjects() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        
        let lessThan30 = Person.find(where: "age < %@", arguments: 30)
        XCTAssertEqual(lessThan30.count, 2)

        let ahmeds = Person.find(where: "name == %@ AND age == %@", arguments: "Ahmed", 29)
        XCTAssertEqual(ahmeds.count, 1)
        XCTAssertEqual(ahmeds.first?.name, "Ahmed")
        
        let onawales = Person.find(where: [.name: "Onawale", .age: 32])
        XCTAssertEqual(onawales.count, 1)
        XCTAssertEqual(onawales.first?.name, "Onawale")
        XCTAssertEqual(onawales.first?.age, 32)
        
        let predicate = NSPredicate(format: "age > 18")
        let greaterThan18 = Person.find(where: predicate)
        XCTAssertEqual(greaterThan18.count, 3)
    }
    
    func testSortingObjects() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        let sorted1 = Person.find(where: [:], sort: [.name: .ASC])
        XCTAssertEqual(sorted1.count, 3)
        XCTAssertEqual(sorted1.first?.name, "Ahmed")
        XCTAssertEqual(sorted1.last?.name, "Onawale")
        
        let name = NSSortDescriptor(key: "name", ascending: false)
        let age = NSSortDescriptor(key: "age", ascending: true)
        let sorted2 = Person.find(where: "age > 10", sort: [name, age])
        XCTAssertEqual(sorted2.first?.name, "Onawale")
        XCTAssertEqual(sorted2.last?.name, "Ahmed")
    }
    
    func testObjectsFetchLimit() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        let justTwo = Person.find(where: "age > 10", limit: 2)
        XCTAssertEqual(justTwo.count, 2)
    }
    
    func testObjectsFetchOffset() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        Person.save() // If context is not saved, the fetchOffset property of NSFetchRequest is ignored
        let skipTwo = Person.find(where: "age > %@", arguments: 10, skip: 2)
        XCTAssertEqual(skipTwo.count, 1)
    }
    
    func testObjectsBatchSize() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        let batch = Person.find(where: "age > %@", arguments: 10, batchSize: 2)
        XCTAssertEqual(batch.count, 3)
    }
    
    func testFindOneObject() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        let ahmed = Person.findOne(where: [.name: "Ahmed"])
        XCTAssertEqual(ahmed?.name, "Ahmed")
        XCTAssertEqual(ahmed?.age, 29)
        
        let ayo = Person.findOne(where: "age < 20")
        XCTAssertEqual(ayo?.name, "Ayo")
        XCTAssertEqual(ayo?.age, 19)
        
        let predicate = NSPredicate(format: "age > 18")
        let someone = Person.findOne(where: predicate)
        XCTAssertNotNil(someone)
    }
    
    func testUpdateObjects() {
        _ = Person.bulkCreate([.name: "ayo", .age: 19], [.name: "ahmed", .age: 29], [.name: "Onawale", .age: 32])
        Person.save()
        
        Person.update(where: "name BEGINSWITH[cd] %@", arguments: "ah", with: [.name: "Ahmed"])
        XCTAssertNotNil(Person.findOne(where: [.name: "Ahmed"]))
        
        let updatedCount = Person.update(where: "age < 30", with: [.age: 30], resultType: .UpdatedObjectsCountResultType) as? Int
        XCTAssertEqual(updatedCount, 2)
        XCTAssertEqual(Person.find(where: "age >= 30").count, 3)

        Person.update(where: [.name: "ayo"], with: [.name: "Ayo"])
        XCTAssertNotNil(Person.findOne(where: [.name: "Ayo"]))

        let age = NSPredicate(format: "age == 30")
        let name = NSPredicate(format: "name == %@", "Ahmed")
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [age, name])
        Person.update(where: predicate, with:[.name: "ahmed", .age: 29])
        XCTAssertNotNil(Person.findOne(where: [.name: "ahmed", .age: 29]))
    }
    
    func testUpsertObject() {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29])
        
        _ = Person.upsert([.name: "Ayo", .age: 19])
        XCTAssertEqual(Person.findAll().count, 2)
        
        _ = Person.upsert([.name: "Onawale", .age: 32])
        XCTAssertEqual(Person.findAll().count, 3)
    }
    
    func testAggregation()  {
        _ = Person.bulkCreate([.name: "Ayo", .age: 19], [.name: "Ahmed", .age: 29], [.name: "Onawale", .age: 32])
        XCTAssertEqual(Person.count(), 3)
        XCTAssertEqual(Person.count(where: "age < 30"), 2)
        XCTAssertEqual(Person.count(where: [.name: "Onawale"]), 1)
        
        let predicate = NSPredicate(format: "name CONTAINS[cd] %@", "e")
        XCTAssertEqual(Person.count(where: predicate), 2)
    }
}