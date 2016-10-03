/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

class GroceryListTableViewController: UITableViewController {

  // MARK: Constants
  let listToUsers = "ListToUsers"
  /// establishes a connection to the Firebase database using the provided path
  /// in short, this property allows for saving and syncing of data to the given location
  let ref = FIRDatabase.database().reference(withPath: "grocery-items")
  /// points to an online location that stores a list of online users
  let usersRef = FIRDatabase.database().reference(withPath: "online")
  
  // MARK: Properties 
  var items: [GroceryItem] = []
  var user: User!
  var userCountBarButtonItem: UIBarButtonItem!

  
  // MARK: UIViewController Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 1
    // listener to receive updates whenever the grocery-items endpoint is modified
    ref.queryOrdered(byChild: "completed").observe(.value, with: { snapshot in
      // 2
      // store latest version of data in local variable
      var newItems: [GroceryItem] = []
      
      // 3
      // Using children, loop through the grocery items from database
      for item in snapshot.children {
        // 4
        // groceryItem struct has an initializer that populates the properties using FIRDataSnapshot
        // after creating an instance, it's added to the array that contains the latest versio of data
        let groceryItem = GroceryItem(snapshot: item as! FIRDataSnapshot)
        newItems.append(groceryItem)
      }
      
      // 5 
      // reassign items to the latest version of the data and reload table
      self.items = newItems
      self.tableView.reloadData()
    })
    
    tableView.allowsMultipleSelectionDuringEditing = false
    
    userCountBarButtonItem = UIBarButtonItem(title: "1",
                                             style: .plain,
                                             target: self,
                                             action: #selector(userCountButtonDidTouch))
    userCountBarButtonItem.tintColor = UIColor.white
    navigationItem.leftBarButtonItem = userCountBarButtonItem
    
    // attach an authentication observer to the Firebase auth object 
    // that in turn assigns the user property when a user successfully signs in
    FIRAuth.auth()!.addStateDidChangeListener { auth, user in
      guard let user = user else { return }
      self.user = User(authData: user)
      
      // 1
      // create a child reference using a user's uid, which is generated when Firebase creates an account
      let currentUserRef = self.usersRef.child(self.user.uid)
      // 2
      // use the reference to save the currents users mail
      currentUserRef.setValue(self.user.email)
      // 3
      // after users go offline, close the app, they will be removed from the list
      currentUserRef.onDisconnectRemoveValue()
    }
    
    // creates an observer that is used to monitor online users
    // when users go on and off it updates the current user coutn in the view
    usersRef.observe(.value, with: { snapshot in
      if snapshot.exists() {
        self.userCountBarButtonItem?.title = snapshot.childrenCount.description
      } else {
        self.userCountBarButtonItem?.title = "0"
      }
    })
  }
  
  // MARK: UITableView Delegate methods
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
    let groceryItem = items[indexPath.row]
    
    cell.textLabel?.text = groceryItem.name
    cell.detailTextLabel?.text = groceryItem.addedByUser
    
    toggleCellCheckbox(cell, isCompleted: groceryItem.completed)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      // so the listener in viewDidLoad() notifies the app of the latest value of the grocery list
      // a removal triggers a value change
      let groceryItem = items[indexPath.row]
      // each grocery item has a firebase reference property named ref, and calling removeValue()
      // causes the listener to fire. the listener has a closure attached that reloads the table view
      // using the latest data
      groceryItem.ref?.removeValue()
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // 1
    // find the cell the user tapped on
    guard let cell = tableView.cellForRow(at: indexPath) else { return }
    // 2
    // get corresponding groceryItem using indexPath row
    let groceryItem = items[indexPath.row]
    // 3
    // negate completed on the item to toggle the status
    let toggledCompletion = !groceryItem.completed
    // 4
    // call toggleCellCheckbox to toggle the visual properties of the cell
    toggleCellCheckbox(cell, isCompleted: toggledCompletion)
    // 5
    // use updateChildValues, passing a dictionary, to update Firebase
    // Note: this method is different than setValue(_:) because it only applies updates
    // setValue(_:) is destructive and replaces the entire value at the reference
    groceryItem.ref?.updateChildValues([
      "completed": toggledCompletion
    ])
  }
  
  func toggleCellCheckbox(_ cell: UITableViewCell, isCompleted: Bool) {
    if !isCompleted {
      cell.accessoryType = .none
      cell.textLabel?.textColor = UIColor.black
      cell.detailTextLabel?.textColor = UIColor.black
    } else {
      cell.accessoryType = .checkmark
      cell.textLabel?.textColor = UIColor.gray
      cell.detailTextLabel?.textColor = UIColor.gray
    }
  }
  
  // MARK: Add Item
  
  @IBAction func addButtonDidTouch(_ sender: AnyObject) {
    let alert = UIAlertController(title: "Grocery Item",
                                  message: "Add an Item",
                                  preferredStyle: .alert)
    
    let saveAction = UIAlertAction(title: "Save",
                                   style: .default) { _ in
                                    
      // 1
      // get textfield and its text from the alert controller
      guard let textField = alert.textFields?.first,
        let text = textField.text else { return }
                                    
      // 2
      // create new grocery item which is not completd
      let groceryItem = GroceryItem(name: text, addedByUser: self.user.email, completed: false)
                                    
      // 3 
      // create a child reference. even when user add duplicated values, the latest will be saved
      let groceryItemRef = self.ref.child(text.lowercased())
      
      // 4
      // use set value to save in the database
      // method expects a dictionary, you can call toAnyObject which turns it into a dictionary
      groceryItemRef.setValue(groceryItem.toAnyObject())
                                    
    }
    
    let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .default)
    
    alert.addTextField()
    
    alert.addAction(saveAction)
    alert.addAction(cancelAction)
    
    present(alert, animated: true, completion: nil)
  }
  
  func userCountButtonDidTouch() {
    performSegue(withIdentifier: listToUsers, sender: nil)
  }
  
}
