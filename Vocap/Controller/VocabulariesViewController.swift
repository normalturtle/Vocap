//
//  ViewController.swift
//  Vocap
//
//  Created by Juhyun Yun on 2023/03/03.
//

import UIKit
import RealmSwift

class VocabulariesViewController: UITableViewController, UITextFieldDelegate {
    //MARK: - Properties
    let realm = try! Realm()
    var vocabularies: Results<Vocabulary>?
    var filteredVocabularies: Results<Vocabulary>?
    var selectedVocabularies: [Vocabulary]?
    var indexs: [Int]? = []
    
    var label = UILabel(frame: .zero)
    var textField: UITextField!
    var searchController = UISearchController(searchResultsController: nil)
    var selectedCategory: Category? {
        didSet {
            loadVocabularies()
        }
    }
    
    var isFiltering: Bool {
        let searchController = self.navigationItem.searchController
        let isActive = searchController?.isActive ?? false
        let isSearchBarHasText = searchController?.searchBar.text?.isEmpty == false
        
        return isActive && isSearchBarHasText
    }
    
    //MARK: - IBOutlets
    @IBOutlet weak var addBtn: UIBarButtonItem!
    @IBOutlet weak var doneBtn: UIBarButtonItem!
    @IBOutlet weak var selectBtn: UIBarButtonItem!
    @IBOutlet weak var selectAllBtn: UIBarButtonItem!
    @IBOutlet weak var moveBtn: UIBarButtonItem!
    @IBOutlet weak var deleteBtn: UIBarButtonItem!
    
    //MARK: - View Life Cycle
    override func viewDidLoad() {
        print(Realm.Configuration.defaultConfiguration.fileURL)
        
        super.viewDidLoad()
        createLableInToolbar()
        
        // read database
        loadVocabularies()
        
        // table view configuration
        tableView.rowHeight = 70.0
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.allowsSelection = false
        tableView.allowsSelectionDuringEditing = true
        tableView.allowsMultipleSelectionDuringEditing = true
        scrollToBottom()
        
        // navigation properties
        doneBtn.isHidden = true
        selectAllBtn.isHidden = true
        moveBtn.isHidden = true
        deleteBtn.isHidden = true
        
        // detecting empty area in UITableView when it is tapped
        let tap = UITapGestureRecognizer(target: self, action: #selector(tableTapped))
        self.tableView.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false // 롱터치? 해야 셀 선택되는거 막아줌
        
        // configure searchbar
        navigationItem.searchController = searchController
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Search words"
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        navigationItem.title = selectedCategory?.name

    }
        
    func scrollToBottom(){
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: IndexPath(row: self.tableView.numberOfRows(inSection: 0)-1, section: 0).row, section: 0)
            if indexPath.row > 0 {
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        deleteEmptyCell()
    }
    
    //MARK: - functions
    func createLableInToolbar() {
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let rightSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        label.text = "No Words"
        label.font = UIFont.systemFont(ofSize: 13)
        label.textAlignment = .center
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.frame.size.width = 100
        let customBarButton = UIBarButtonItem(customView: label)
        setToolbarItems([moveBtn, space, customBarButton, rightSpace, deleteBtn], animated: false)
    }
    
    func getTextOfNumber(_ number: Int) -> String {
        if number < 2 {
            return "\(number) Word"
        } else {
            return "\(number) Words"
        }
    }
    
    
    //MARK: - IBActions
    @IBAction func addBtnTapped(_ sender: Any) {
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
        }
        
        addNewVocab()
    }
    
    @IBAction func doneBtnTapped(_ sender: Any) {
        deleteEmptyCell()
        
        if tableView.isEditing {
            selectBtn.image = UIImage(systemName: "checkmark.circle")
            setBarButton()
            tableView.setEditing(false, animated: true)
        }
        
        self.view.endEditing(true)
        tableView.reloadData()
        
    }
    
    func deleteEmptyCell() {
        let indexPath = IndexPath(row: vocabularies!.count-1, section: 0)
        
        if let cell = tableView.cellForRow(at: indexPath) as? VocabularyCell {
            if cell.vocabTextField.text == "" {
                deleteVocabularies(at: indexPath.row)
            }
        }
    }
    
    @IBAction func selectBtnTapped(_ sender: UIBarButtonItem) {
        if label.text == "No Words" {
            return
        }
        
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
        }
        
        tableView.setEditing(true, animated: true)
        changeToolbarItems()
        setBarButton()
    }
    
    @IBAction func selectAllTapped(_ sender: UIBarButtonItem) {
        var indexPaths: [IndexPath] = []
        
        for row in 0..<tableView.numberOfRows(inSection: 0) {
            let indexPath = IndexPath(row: row, section: 0)
            indexPaths.append(indexPath)
        }
        
        if tableView.indexPathsForSelectedRows?.count == tableView.numberOfRows(inSection: 0) {
            for indexPath in indexPaths {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        } else {
            for indexPath in indexPaths {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
        changeToolbarItems()
    }
    
    @IBAction func moveBtnTapped(_ sender: UIBarButtonItem) {
        getSelectedVocabs()
        performSegue(withIdentifier: "goToSelection", sender: self)
    }
    
    @IBAction func deleteBtnTapped(_ sender: UIBarButtonItem) {
        getSelectedVocabs()
        
        let alert = UIAlertController(title: nil, message: "\(selectedVocabularies!.count)개의 단어가 삭제됩니다.", preferredStyle: .actionSheet)
        
        let action = UIAlertAction(title: "삭제", style: .default, handler: { [self] UIAlertAction in
            if let selectedVocabularies {
                do {
                    try self.realm.write {
                        self.realm.delete(selectedVocabularies)
                    }
                } catch {
                    print("Error deleting vocabs: \(error.localizedDescription)")
                }
                self.tableView.reloadData()
            }
            
            
            if self.tableView.isEditing {
                self.setBarButton()
                self.tableView.setEditing(false, animated: true)
            }
            
            self.view.endEditing(true)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        action.setValue(UIColor.systemRed, forKey: "titleTextColor")
        
        alert.addAction(action)
                
        present(alert, animated: true)
    }
    
    
    func getSelectedVocabs() {
        selectedVocabularies = []
        
        if let selectedRows = tableView.indexPathsForSelectedRows {
            let indexs = selectedRows.map{ $0[1] }.sorted()
            if isFiltering {
                if let filteredVocabularies {
                    selectedVocabularies = indexs.map{ filteredVocabularies[$0] }
                }
            } else {
                if let vocabularies {
                    selectedVocabularies = indexs.map{ vocabularies[$0] }
                }
            }
        }
        
        getIndexs()
    }
    
    func getIndexs() {
        indexs = []
        
        if let selectedVocabularies {
            for vocab in selectedVocabularies {
                if let index = selectedCategory?.vocabs.index(of: vocab) {
                    indexs?.append(index)
                }
            }
            indexs?.sort()
        }
    }
        
    //MARK: - Add New Vocabulary
    func addNewVocab() {
        // add 버튼 연속으로눌렀을때 여러개 추가되는거 방지
        deleteEmptyCell()
        
        if searchController.isActive {
            searchController.isActive = false
        }
        
        
        if tableView.isEditing {
            return
        }
        
        let newVocabulary = Vocabulary()
        newVocabulary.dateCreated = Date()
        saveVocabularies(vocabulary: newVocabulary)
        tableView.reloadData()
        
        let indexPath = IndexPath(row: vocabularies!.count-1, section: 0)
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
        
        if let cell = self.tableView.cellForRow(at: indexPath) as? VocabularyCell {
            cell.vocabTextField.becomeFirstResponder()
        }
    }
    
    func setBarButton() {
        addBtn.isHidden = !addBtn.isHidden
        doneBtn.isHidden = !doneBtn.isHidden
        selectBtn.isHidden = !selectBtn.isHidden
        
        if tableView.isEditing {
            deleteBtn.isHidden = !deleteBtn.isHidden
            moveBtn.isHidden = !moveBtn.isHidden
            selectAllBtn.isHidden = !selectAllBtn.isHidden
        }
    }
    
    //MARK: - TableView Delegate Methods
    @objc func tableTapped(tap:UITapGestureRecognizer) {
        let location = tap.location(in: self.tableView)
        let path = self.tableView.indexPathForRow(at: location)
        
        if path == nil {
            if addBtn.isHidden {
                deleteEmptyCell()
            } else {
                addNewVocab()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        label.text = "No Words"
        
        return isFiltering ? filteredVocabularies?.count ?? 1 : vocabularies?.count ?? 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VocabCell", for: indexPath) as! VocabularyCell
        guard let vocabulary = vocabularies?[indexPath.row] else {fatalError()}
        
        if isFiltering {
            if let filteredVocabulary = filteredVocabularies?[indexPath.row] {
                label.text = getTextOfNumber(filteredVocabularies?.count ?? 0)
                cell.vocabTextField.text = filteredVocabulary.vocab
                cell.meaningTextField.text = filteredVocabulary.meaning
            }
        } else {
            label.text = getTextOfNumber(vocabularies?.count ?? 0)
            cell.vocabTextField.text = vocabulary.vocab
            cell.meaningTextField.text = vocabulary.meaning
        }
        
        // 체크포인트 - 셀 스와이핑 했을 때 스크롤 하면 단어 0개로 표시되는거 고쳐야됨
        if tableView.isEditing {
            changeToolbarItems()
        }
        
        cell.vocabTextField.autocapitalizationType = .none
        
        cell.vocabTextField.tag = indexPath.row * 2
        cell.meaningTextField.tag = cell.vocabTextField.tag + 1
        
        cell.vocabTextField.delegate = self
        cell.meaningTextField.delegate = self
        
        
        cell.vocabCallback = { str in
            try! self.realm.write {
                vocabulary.vocab = str
            }
        }
        
        cell.meaningCallback = { str in
            try! self.realm.write {
                vocabulary.meaning = str
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let delete = UIContextualAction(style: .normal, title: nil) { (UIContextualAction, UIView, success: @escaping (Bool) -> Void) in
            self.deleteVocabularies(at: indexPath.row)
            success(true)
        }
        
        delete.backgroundColor = .red
        delete.image = UIImage(systemName: "trash.fill")
        
        return UISwipeActionsConfiguration(actions:[delete])
    }
    
    
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? VocabularyCell else { fatalError() }
        
        if cell.vocabTextField.text != "" {
            performSegue(withIdentifier: "goToDetail", sender: indexPath.row)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let nextNav = segue.destination as? UINavigationController else { fatalError() }
        
        if let detailViewController = nextNav.topViewController as? DetailViewController {
            if let index = sender as? Int {
                detailViewController.selectedVocabulary = vocabularies?[index]
            }
        }
                
        if let selectionVC = nextNav.topViewController as? SelectionViewController {
            selectionVC.selectedVocabs = selectedVocabularies
            selectionVC.selectedCategory = selectedCategory
            selectionVC.indexs = indexs
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        changeToolbarItems()
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        changeToolbarItems()
    }

    func changeToolbarItems() {
        let a = tableView.indexPathsForSelectedRows
        
        if a == nil {
            moveBtn.isEnabled = false
            deleteBtn.isEnabled = false
            label.text = "0 Selected"
        } else {
            moveBtn.isEnabled = true
            deleteBtn.isEnabled = true
            label.text = "\(a!.count) Selected"
        }
    }
    
    //MARK: - Data Manipulation Methods
    func saveVocabularies(vocabulary: Vocabulary) {
        do {
            try realm.write {
                selectedCategory?.vocabs.append(vocabulary)
            }
        } catch {
            print("Error saving notes, \(error)")
        }
        
        tableView.reloadData()
    }
    
    func loadVocabularies() {
        vocabularies = selectedCategory?.vocabs.sorted(byKeyPath: "dateCreated", ascending: true)
        
        tableView.reloadData()
    }
    
    func deleteVocabularies(at indexPath: Int) {
        if let vocabulary = vocabularies?[indexPath] {
            do {
                try realm.write {
                    self.realm.delete(vocabulary)
                }
            } catch {
                print("Error deleting notes, \(error)")
            }
            tableView.reloadData()
        }
        
    }
    
    //MARK: - TextField Delegate Methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let tag = textField.tag
        let row = tag / 2
        
        guard let cell = textField.superview?.superview as? VocabularyCell else { fatalError() }
        
        if tag % 2 == 0 { // on vocabTF
            if textField.text == "" {
                textField.endEditing(true)
                deleteVocabularies(at: row)
            } else {
                cell.meaningTextField.becomeFirstResponder()
            }
        }
        
        if tag % 2 == 1 { // on meaningTF
            guard let vocabularies = vocabularies?.count else { fatalError() }
            let indexPath = IndexPath(row: row + 1, section: 0)
            
            if row < vocabularies - 1 {
                let nextCell = tableView.cellForRow(at: indexPath) as! VocabularyCell
                nextCell.vocabTextField.becomeFirstResponder()
            } else {
                addNewVocab()
//                if textField.text == "" {
//                    deleteVocabularies(at: row)
//                } else {
//                    addNewVocab()
//                }
            }
        }
        
        return true
        
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        setBarButton()
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if tableView.isEditing {
            return false
        }
        
        setBarButton()
        return true
    }
}

extension VocabulariesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        
        filteredVocabularies = vocabularies?.filter("vocab CONTAINS[cd] %@", text).sorted(byKeyPath: "vocab", ascending: true)
        
        tableView.reloadData()
    }
    
    
}
