//
//  CheckoutViewController.swift
//  ShopClient
//
//  Created by Evgeniy Antonov on 12/20/17.
//  Copyright © 2017 Evgeniy Antonov. All rights reserved.
//

import UIKit

private let kPlaceOrderHeightVisible: CGFloat = 50
private let kPlaceOrderHeightInvisible: CGFloat = 0

class CheckoutViewController: BaseViewController<CheckoutViewModel>, SeeAllHeaderViewProtocol, CheckoutCombinedProtocol {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var placeOrderHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var placeOrderButton: UIButton!
    
    private var tableDataSource: CheckoutTableDataSource!
    private var tableDelegate: CheckoutTableDelegate!
    private var destinationAddress: Address?
    private var selectedProductVariant: ProductVariant!
    
    override func viewDidLoad() {
        viewModel = CheckoutViewModel()
        super.viewDidLoad()

        setupViews()
        setupTableView()
        setupViewModel()
        loadData()
    }
    
    private func setupViews() {
        addCloseButton()
        title = "ControllerTitle.Checkout".localizable
        placeOrderButton.setTitle("Button.PlaceOrder".localizable.uppercased(), for: .normal)
        updatePlaceOrderButtonUI()
    }
    
    private func setupTableView() {
        let cartNib = UINib(nibName: String(describing: CheckoutCartTableViewCell.self), bundle: nil)
        tableView?.register(cartNib, forCellReuseIdentifier: String(describing: CheckoutCartTableViewCell.self))
        
        let shippingAddressAddNib = UINib(nibName: String(describing: CheckoutShippingAddressAddTableCell.self), bundle: nil)
        tableView.register(shippingAddressAddNib, forCellReuseIdentifier: String(describing: CheckoutShippingAddressAddTableCell.self))
        
        let shippingAddressEditNib = UINib(nibName: String(describing: CheckoutShippingAddressEditTableCell.self), bundle: nil)
        tableView.register(shippingAddressEditNib, forCellReuseIdentifier: String(describing: CheckoutShippingAddressEditTableCell.self))
        
        let paymentAddNib = UINib(nibName: String(describing: CheckoutPaymentAddTableCell.self), bundle: nil)
        tableView.register(paymentAddNib, forCellReuseIdentifier: String(describing: CheckoutPaymentAddTableCell.self))
        
        let paymentEditNib = UINib(nibName: String(describing: CheckoutPaymentEditTableCell.self), bundle: nil)
        tableView.register(paymentEditNib, forCellReuseIdentifier: String(describing: CheckoutPaymentEditTableCell.self))
        
        tableDataSource = CheckoutTableDataSource(delegate: self)
        tableView?.dataSource = tableDataSource
        
        tableDelegate = CheckoutTableDelegate(delegate: self)
        tableView?.delegate = tableDelegate
        
        tableView?.contentInset = TableView.defaultContentInsets
    }
    
    private func setupViewModel() {
        viewModel.checkout.asObservable()
            .subscribe(onNext: { [weak self] _ in
                self?.tableView.reloadData()
            })
            .disposed(by: disposeBag)
        
        placeOrderButton.rx.tap
            .bind(to: viewModel.placeOrderPressed)
            .disposed(by: disposeBag)
    }
    
    private func loadData() {
        viewModel.loadData(with: disposeBag)
    }
    
    private func closeAddressFormController() {
        navigationController?.popToViewController(self, animated: true)
    }
    
    // MARK: - CheckoutTableDataSourceProtocol
    func cartProducts() -> [CartProduct] {
        return viewModel.cartItems
    }
    
    func shippingAddress() -> Address? {
        return viewModel.checkout.value?.shippingAddress
    }
    
    func billingAddress() -> Address? {
        return viewModel.billingAddress
    }
    
    func creditCard() -> CreditCard? {
        return viewModel.creditCard
    }
    
    // MARK: - CheckoutShippingAddressAddCellProtocol
    func didTapAddNewAddress() {
        performSegue(withIdentifier: SegueIdentifiers.toAddressForm, sender: self)
    }
    
    // MARK: - CheckoutShippingAddressEditCellProtocol
    func didTapEdit() {
        if let checkoutId = viewModel.checkout.value?.id, let address = viewModel.checkout.value?.shippingAddress {
            processUpdateAddress(with: checkoutId, address: address)
        }
    }
    
    // MARK: - private
    private func processUpdateAddress(with checkoutId: String, address: Address) {
        if Repository.shared.isLoggedIn() {
            openAddressList(with: checkoutId, address: address)
        } else {
            openAddressForm(with: address)
        }
    }
    
    private func openAddressList(with checkoutId: String, address: Address) {
        destinationAddress = address
        performSegue(withIdentifier: SegueIdentifiers.toAddressList, sender: self)
    }
    
    private func openAddressForm(with address: Address) {
        performSegue(withIdentifier: SegueIdentifiers.toAddressForm, sender: self)
    }
    
    private func updatePlaceOrderButtonUI() {
        let visible = viewModel.checkout.value != nil && viewModel.creditCard != nil && viewModel.billingAddress != nil
        placeOrderButton.isHidden = !visible
        placeOrderHeightConstraint.constant = visible ? kPlaceOrderHeightVisible : kPlaceOrderHeightInvisible
    }
    
    private func returnFlowToSelf() {
        navigationController?.popToViewController(self, animated: true)
    }
    
    // MARK: - SeeAllHeaderViewProtocol
    func didTapSeeAll(type: SeeAllViewType) {
        if type == .myCart {
            // TODO:
        }
    }
    
    // MARK: - CheckoutPaymentAddCellProtocol
    func didTapAddPayment() {
        performSegue(withIdentifier: SegueIdentifiers.toPaymentType, sender: self)
    }
    
    // MARK: - CheckoutTableDelegateProtocol
    func checkout() -> Checkout? {
        return viewModel.checkout.value
    }
    
    // MARK: - CheckoutCartTableViewCellDelegate
    func didSelectItem(with productVariantId: String, at index: Int) {
        selectedProductVariant = viewModel.productVariant(with: productVariantId)
        // TODO: Open product details screen with selectedProductVariant
        // performSegue(withIdentifier: SegueIdentifiers.toProductDetails, sender: self)
    }
    
    // MARK: - segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let addressListViewController = segue.destination as? AddressListViewController {
            addressListViewController.addressListType = .shipping
            addressListViewController.selectedAddress = destinationAddress
            addressListViewController.completion = { [weak self] (address) in
                self?.navigationController?.popViewController(animated: true)
                self?.viewModel.updateCheckoutShippingAddress(with: address, isDefaultAddress: false)
            }
        } else if let addressFormViewController = segue.destination as? AddressFormViewController {
            addressFormViewController.completion = { [weak self] (address, isDefaultAddress) in
                self?.viewModel.updateCheckoutShippingAddress(with: address, isDefaultAddress: isDefaultAddress)
            }
        } else if let paymentTypeViewController = segue.destination as? PaymentTypeViewController {
            paymentTypeViewController.completion = { [weak self] (billingAddress, card) in
                self?.viewModel.billingAddress = billingAddress
                self?.viewModel.creditCard = card
                self?.tableView.reloadData()
                self?.updatePlaceOrderButtonUI()
                self?.returnFlowToSelf()
            }
        }
    }
}