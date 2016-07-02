//
//  AllQandAsTableViewController.swift
//  Pollster
//
//  Created by Tom Yu on 7/2/16.
//  Copyright © 2016 kangleyu. All rights reserved.
//

import UIKit
import CloudKit

class AllQandAsTableViewController: UITableViewController {
    
    var allQandAs = [CKRecord]() { didSet { tableView.reloadData() }}
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        fetchAllQandAs()
        iCloudSubscribeToQandAs()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        iCloundUnsubscribeToQandAs()
    }
    
    private let database = CKContainer.defaultContainer().publicCloudDatabase
    
    private func fetchAllQandAs() {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let query = CKQuery(recordType: Cloud.Entity.QandA, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Cloud.Attribute.Question, ascending: true)]
        database.performQuery(
            query,
            inZoneWithID: nil) { (records, error) in
                if records != nil {
                    dispatch_async(dispatch_get_main_queue()){
                        self.allQandAs = records!
                    }
                }
        }
    }
    
    // MARK: Subscription
    private let subscriptionID = Constants.CloudSubscriptionID
    
    private var cloudKitObserver: NSObjectProtocol?
    
    private func iCloudSubscribeToQandAs() {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let subscription = CKSubscription(
            recordType: Cloud.Entity.QandA,
            predicate: predicate,
            subscriptionID: self.subscriptionID,
            options: [.FiresOnRecordCreation, .FiresOnRecordDeletion])
        //subscription.notificationInfo = ...
        database.saveSubscription(subscription) { (savedSubscription, error) in
                if error?.code == CKErrorCode.ServerRejectedRequest.rawValue {
                    // ignore
                } else if error != nil {
                    // other errors
                }
        }
        
        cloudKitObserver = NSNotificationCenter.defaultCenter().addObserverForName(
            CloudKitNotifications.NotificationReceived,
            object: nil,
            queue: NSOperationQueue.mainQueue(),
            usingBlock: { (notification) in
                if let ckqn = notification.userInfo?[CloudKitNotifications.NotificationKey] as? CKQueryNotification {
                    self.iCloudHandleSubscriptionNotification(ckqn)
                }
        })
    }
    
    private func iCloudHandleSubscriptionNotification(ckqn: CKQueryNotification) {
        if ckqn.subscriptionID == self.subscriptionID {
            if let recordID = ckqn.recordID {
                switch ckqn.queryNotificationReason {
                case .RecordCreated:
                    database.fetchRecordWithID(recordID) { (record, error) in
                        if record != nil {
                            dispatch_async(dispatch_get_main_queue()){
                                self.allQandAs = (self.allQandAs + [record!]).sort {
                                    return $0.question < $1.question
                                }
                            }
                        }
                    }
                case .RecordDeleted:
                    dispatch_async(dispatch_get_main_queue()){
                        self.allQandAs = self.allQandAs.filter { $0.recordID != recordID }
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func iCloundUnsubscribeToQandAs() {
        database.deleteSubscriptionWithID(self.subscriptionID) { (subscription, error) in
            // handle it
        }
        NSNotificationCenter.defaultCenter().removeObserver(self.cloudKitObserver!)
    }
    
    // MARK: UITableViewDataSource
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allQandAs.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(Constants.QandACell, forIndexPath: indexPath)
        cell.textLabel?.text = allQandAs[indexPath.row].question
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return allQandAs[indexPath.row].wasCreatedByThisUser;
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let record = allQandAs[indexPath.row]
            database.deleteRecordWithID(record.recordID) { (deletedRecord, error) in
                // handle errors
            }
            allQandAs.removeAtIndex(indexPath.row)
        }
    }
    
    // MARK: Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == Constants.ShowQandASegueIdentifier {
            if let ckQandATVC = segue.destinationViewController as? CloudQandATableViewController {
                if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPathForCell(cell) {
                    ckQandATVC.ckQandARecord = allQandAs[indexPath.row]
                } else {
                    ckQandATVC.ckQandARecord = CKRecord(recordType: Cloud.Entity.QandA)
                }
            }
        }
    }

}
