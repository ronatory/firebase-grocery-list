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
  
  // MARK: Properties 
  var items: [GroceryItem] = []
  var user: User!
  var userCountBarButtonItem: UIBarButtonItem!

  
  // MARK: UIViewController Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // eventtype .value what type to listen, add, remove and changed
    // app is notified via the closure, the snapshot represents the most recent data
    ref.observe(.value, with: { snapshot in
      print(snapshot.value)
    })
    
    tableView.allowsMultipleSelectionDuringEditing = false
    
    userCountBarButtonItem = UIBarButtonItem(title: "1",
                                             style: .plain,
                                             target: self,
                                             action: #selector(userCountButtonDidTouch))
    userCountBarButtonItem.tintColor = UIColor.white
    navigationItem.leftBarButtonItem = userCountBarButtonItem
    
    user = User(uid: "FakeId", email: "hungry@person.food")
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
      items.remove(at: indexPath.row)
      tableView.reloadData()
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { return }
    var groceryItem = items[indexPath.row]
    let toggledCompletion = !groceryItem.completed
    
    toggleCellCheckbox(cell, isCompleted: toggledCompletion)
    groceryItem.completed = toggledCompletion
    tableView.reloadData()
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
