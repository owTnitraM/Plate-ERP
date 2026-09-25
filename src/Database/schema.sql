-- 1. Foundation

-- COMPANIES TABLE -- Stores information about the company.
CREATE TABLE Companies (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    registration_number VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- PERMISSIONS TABLE -- List of system permissions a company needs, such as: UPDATE stock, salary, other employees permisions. DELETE. ADD. and other permissions.
CREATE TABLE Permissions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. Polymorphic Addresses Table (Updated ENUM to support all entities)

-- ADDRESSES TABLE -- Stores an addresses information. Needs additional validation to maintain entry consistency.
CREATE TABLE Addresses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    owner_type ENUM('customer', 'employee', 'branch', 'supplier', 'company') NOT NULL,
    owner_id BIGINT UNSIGNED NOT NULL,
    label VARCHAR(50) DEFAULT NULL,
    postal_code VARCHAR(20) NOT NULL, -- CEP
    street_type VARCHAR(50) DEFAULT NULL, -- TIPO DE LOGRADOURO: AVENIDA, RUA, ETC
    street_name VARCHAR(255) NOT NULL,
    building_number VARCHAR(20) NOT NULL,
    complement VARCHAR(255) DEFAULT NULL, -- COMPLEMENTO
    block_number VARCHAR(20) DEFAULT NULL, -- BLOCO (PARA APARTAMENTOS)
    floor VARCHAR(10) DEFAULT NULL, -- ANDAR (PARA APARTAMENTOS)
    apartment_number VARCHAR(20) DEFAULT NULL, -- NUMERO DO APARTAMENTO
    neighborhood VARCHAR(255) NOT NULL, -- BAIRRO
    city VARCHAR(100) NOT NULL,
    ibge_city_code VARCHAR(10) DEFAULT NULL,
    state_code CHAR(2) NOT NULL, -- UF
    country_code CHAR(2) NOT NULL,
    reference_point VARCHAR(255) DEFAULT NULL,
    latitude DECIMAL(10, 8) DEFAULT NULL,
    longitude DECIMAL(11,8) DEFAULT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,

    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_owner (owner_type, owner_id),
    INDEX idx_postal_code (postal_code)
);

-- 3. Security Roles

-- ROLES TABLE -- List of all positions in a company. Decided by each company.
CREATE TABLE Roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255) DEFAULT NULL,
    base_salary DECIMAL(16,2) DEFAULT NULL,     -- starting salary for this position
    commission_rate DECIMAL(10,2) DEFAULT NULL,  -- uniform for every employee in this role; NULL = no commission
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uq_role_company_name (company_id, name),
    FOREIGN KEY (company_id) REFERENCES Companies(id)
);

-- ROLE_PERMISSIONS TABLE -- List of all default permissions an employee with a specific role has (N:N).
CREATE TABLE Role_Permissions (
    role_id BIGINT UNSIGNED NOT NULL,
    permission_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES Roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES Permissions(id) ON DELETE CASCADE
);

-- 4. Operations & People

-- EMPLOYEES TABLE -- List of all employees and their information.
CREATE TABLE Employees (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    role_id BIGINT UNSIGNED NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    cpf CHAR(11) NOT NULL,                      -- always required, regardless of employment_type
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20) DEFAULT NULL,
    password_hash VARCHAR(255) NOT NULL,
    employment_type ENUM('clt', 'pj', 'intern', 'temporary') DEFAULT NULL,
    cnpj CHAR(14) DEFAULT NULL,                 -- required only when employment_type = 'pj'
    business_name VARCHAR(255) DEFAULT NULL,    -- razão social of their PJ entity; required only when employment_type = 'pj'
    weekly_hours DECIMAL(4,2) DEFAULT NULL,
    hire_date DATE NOT NULL,
    termination_date DATE DEFAULT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_employee_company_cpf (company_id, cpf),
    UNIQUE KEY uq_employee_company_cnpj (company_id, cnpj),
    FOREIGN KEY (company_id) REFERENCES Companies(id),
    FOREIGN KEY (role_id) REFERENCES Roles(id),

    CHECK (
        employment_type <> 'pj' 
        OR (cnpj IS NOT NULL AND CHAR_LENGTH(cnpj) = 14 AND business_name IS NOT NULL)
    )
);

-- EMPLOYEE_SALARY_HISTORY TABLE -- Tracks every salary change for an employee over time, so past raises are never overwritten.
CREATE TABLE Employee_Salary_History (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT UNSIGNED NOT NULL,
    salary DECIMAL(16,2) NOT NULL,
    effective_date DATE NOT NULL,           -- date this salary took effect
    reason VARCHAR(255) DEFAULT NULL,       -- 'hire', 'annual raise', 'promotion', etc.
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE CASCADE
);

-- EMPLOYEE_REVIEWS TABLE -- Ratings and feedback left by customers about an employee, optionally tied to a specific sale.
CREATE TABLE Employee_Reviews (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT UNSIGNED NOT NULL,
    customer_id BIGINT UNSIGNED DEFAULT NULL,     -- the customer who left the rating
    sales_order_id BIGINT UNSIGNED DEFAULT NULL,  -- which transaction this review is about
    rating DECIMAL(3,2) NOT NULL,
    comments VARCHAR(255) DEFAULT NULL,
    review_date DATE NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES Customers(id) ON DELETE SET NULL,
    FOREIGN KEY (sales_order_id) REFERENCES Sales_Orders(id) ON DELETE SET NULL
);

-- BRANCHES TABLE -- A single entity of the company, such as a store or warehouse or headquarters.
CREATE TABLE Branches (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    manager_id BIGINT UNSIGNED DEFAULT NULL,  -- direct/local branch manager, optional
    name VARCHAR(255) NOT NULL,
    branch_type ENUM('store', 'warehouse', 'headquarters', 'distribution_center', 'office') NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES Employees(id) ON DELETE SET NULL
);
-- EMPLOYEE_BRANCHES TABLE -- N:N table that connects which employee works at which branch.
CREATE TABLE Employee_Branches (
    employee_id BIGINT UNSIGNED NOT NULL,
    branch_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (employee_id, branch_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(id),
    FOREIGN KEY (branch_id) REFERENCES Branches(id)
);

-- EMPLOYEE_PERMISSIONS -- List extra permissions grants or revokes that employees can have (N:N).
CREATE TABLE Employee_Permissions (
    employee_id BIGINT UNSIGNED NOT NULL,
    permission_id BIGINT UNSIGNED NOT NULL,
    is_granted BOOLEAN NOT NULL DEFAULT TRUE, -- TRUE = explicit grant, FALSE = explicit revoke/deny
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (employee_id, permission_id),
    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES Permissions(id) ON DELETE CASCADE
);

-- STATE_MANAGERS TABLE -- Stores who is the state manager and manager changes.
CREATE TABLE State_Managers (
    company_id BIGINT UNSIGNED NOT NULL,
    country_code CHAR(2) NOT NULL,
    state_code CHAR(2) NOT NULL,
    employee_id BIGINT UNSIGNED DEFAULT NULL,  -- NULL = no manager currently assigned
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (company_id, country_code, state_code),
    FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE SET NULL
);

-- COUNTRY_MANAGERS TABLE -- Stores who is the country manager and manager changes.
CREATE TABLE Country_Managers (
    company_id BIGINT UNSIGNED NOT NULL,
    country_code CHAR(2) NOT NULL,
    employee_id BIGINT UNSIGNED DEFAULT NULL,  -- NULL = no manager currently assigned
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (company_id, country_code),
    FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE SET NULL
);

-- CUSTOMERS TABLE -- List of customers and their information.
CREATE TABLE Customers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    customer_type ENUM('individual', 'business') NOT NULL DEFAULT 'individual',
    first_name VARCHAR(100) DEFAULT NULL,       -- required when customer_type = 'individual'
    last_name VARCHAR(100) DEFAULT NULL,        -- required when customer_type = 'individual'
    company_name VARCHAR(255) DEFAULT NULL,     -- required when customer_type = 'business'
    document_number VARCHAR(14) NOT NULL,       -- CPF (11 digits) or CNPJ (14 digits), digits only
    email VARCHAR(255) DEFAULT NULL,
    phone VARCHAR(50) DEFAULT NULL,
    marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_consent_updated_at DATETIME DEFAULT NULL,  -- when consent was last given/withdrawn
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_customer_company_document (company_id, document_number),
    FOREIGN KEY (company_id) REFERENCES Companies(id),

    CHECK (
        (customer_type = 'individual' AND first_name IS NOT NULL AND last_name IS NOT NULL AND CHAR_LENGTH(document_number) = 11)
        OR
        (customer_type = 'business' AND company_name IS NOT NULL AND CHAR_LENGTH(document_number) = 14)
    )
);

-- CUSTOMERS SUPPLIERS -- List of suppliers and their information.
CREATE TABLE Suppliers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(255) NOT NULL,
    cnpj CHAR(14) NOT NULL,
    contact_email VARCHAR(255) DEFAULT NULL,
    phone VARCHAR(50) DEFAULT NULL,
    payment_terms_days SMALLINT UNSIGNED DEFAULT NULL,  -- e.g. 30, 60, 90
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_supplier_company_cnpj (company_id, cnpj),
    FOREIGN KEY (company_id) REFERENCES Companies(id)
);

-- SUPPLIER_REVIEWS TABLE -- Ratings and feedback left by employees about a supplier tied to a specific order.
CREATE TABLE Supplier_Reviews (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    supplier_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED DEFAULT NULL,        -- who left the review
    purchase_order_id BIGINT UNSIGNED DEFAULT NULL,  -- which order this review is about
    rating DECIMAL(3,2) NOT NULL,
    on_time_delivery BOOLEAN DEFAULT NULL,            -- quick structured flag, in addition to the free-form rating
    comments VARCHAR(255) DEFAULT NULL,
    review_date DATE NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (supplier_id) REFERENCES Suppliers(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE SET NULL,
    FOREIGN KEY (purchase_order_id) REFERENCES Purchase_Orders(id) ON DELETE SET NULL
);

-- 5. Inventory Catalog

-- PRODUCT_CATEGORIES TABLE -- Stores all the categories of products a company stipulated.
CREATE TABLE Product_Categories (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    parent_category_id BIGINT UNSIGNED DEFAULT NULL,  -- for subcategories (e.g. Beverages > Sodas); NULL = top-level
    name VARCHAR(100) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_category_company_name (company_id, name),
    FOREIGN KEY (company_id) REFERENCES Product_Categories(id),
    FOREIGN KEY (parent_category_id) REFERENCES Product_Categories(id) ON DELETE SET NULL
);

-- PRODUCTS TABLE -- List of all products that can be brought and sold, also contains their info.
CREATE TABLE Products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    supplier_id BIGINT UNSIGNED DEFAULT NULL,
    category_id BIGINT UNSIGNED DEFAULT NULL,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(255) DEFAULT NULL,
    sku VARCHAR(100) NOT NULL,
    barcode VARCHAR(14) DEFAULT NULL,   -- EAN-8/12/13 or GTIN-14
    ncm_code CHAR(8) DEFAULT NULL,      -- Brazilian tax classification (Nomenclatura Comum do Mercosul)
    base_price DECIMAL(16, 2) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_product_company_sku (company_id, sku),
    UNIQUE KEY uq_product_company_barcode (company_id, barcode),
    FOREIGN KEY (company_id) REFERENCES Companies(id),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(id) ON DELETE SET NULL,
    FOREIGN KEY (category_id) REFERENCES Product_Categories(id) ON DELETE SET NULL
);

-- INVENTORY TABLE -- List of the product inventory by branch.
CREATE TABLE Inventory (
    branch_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    reserved_quantity INT NOT NULL DEFAULT 0,   -- committed to pending sales orders, not yet fulfilled
    available_quantity INT GENERATED ALWAYS AS (quantity - reserved_quantity) STORED,
    reorder_point INT DEFAULT NULL,             -- flag for reorder when quantity falls at/below this
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (branch_id, product_id),
    FOREIGN KEY (branch_id) REFERENCES Branches(id),
    FOREIGN KEY (product_id) REFERENCES Products(id)
);

-- INVENTORY_MOVEMENTS -- Stores the changes in an items stock quantity, and the type of change.
CREATE TABLE Inventory_Movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    branch_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED DEFAULT NULL,   -- who triggered this movement, if applicable
    movement_type ENUM('purchase', 'sale', 'transfer_in', 'transfer_out', 'adjustment', 'damage', 'return') NOT NULL,
    quantity_change INT NOT NULL,               -- positive = stock added, negative = stock removed
    reference_type ENUM('purchase_order', 'sales_order', 'manual') DEFAULT NULL,
    reference_id BIGINT UNSIGNED DEFAULT NULL,  -- points to Purchase_Orders.id or Sales_Orders.id, depending on reference_type
    notes VARCHAR(255) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (branch_id) REFERENCES Branches(id),
    FOREIGN KEY (product_id) REFERENCES Products(id),
    FOREIGN KEY (employee_id) REFERENCES Employees(id) ON DELETE SET NULL
);

/* OBS
START TRANSACTION;

INSERT INTO Inventory_Movements 
    (branch_id, product_id, employee_id, movement_type, quantity_change, reference_type, reference_id, notes)
VALUES 
    (12, 45, 3, 'sale', -2, 'sales_order', 987, NULL);

INSERT INTO Inventory (branch_id, product_id, quantity)
VALUES (12, 45, -2)
ON DUPLICATE KEY UPDATE quantity = quantity + (-2);

COMMIT; */

-- 6. Transactions

-- PURCHASE_ORDERS TABLE -- Contains the general order info.
CREATE TABLE Purchase_Orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    branch_id BIGINT UNSIGNED NOT NULL,
    supplier_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED NOT NULL,
    status ENUM('draft', 'pending_approval', 'approved', 'ordered', 'received', 'cancelled') NOT NULL DEFAULT 'draft',
    /* total_amount DECIMAL(16, 2) NOT NULL DEFAULT 0, IMPLICIT SUM ALL LINES */
    expected_delivery_date DATE DEFAULT NULL,
    received_at DATETIME DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (company_id) REFERENCES Companies(id),
    FOREIGN KEY (branch_id) REFERENCES Branches(id),
    FOREIGN KEY (supplier_id) REFERENCES Suppliers(id),
    FOREIGN KEY (employee_id) REFERENCES Employees(id)
);

-- PURCHASE_LINES TABLE -- Contains the specifics of orders, such as specific products and amounts.
CREATE TABLE Purchase_Lines (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    purchase_order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT NOT NULL,
    unit_cost DECIMAL(16, 2) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (purchase_order_id) REFERENCES Purchase_Orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(id)
);

/* OBS
// When purchase order status flips to 'received':
for (const line of purchaseOrderLines) {
    await recordInventoryMovement(connection, {
        branchId: purchaseOrder.branch_id,
        productId: line.product_id,
        employeeId: currentEmployee.id,
        movementType: 'purchase',
        quantityChange: line.quantity,       // positive — stock increases
        referenceType: 'purchase_order',
        referenceId: purchaseOrder.id,
        notes: null
    });
} */

-- SALES_ORDERS TABLE -- Contains the general sale info.
CREATE TABLE Sales_Orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    branch_id BIGINT UNSIGNED NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED NOT NULL,
    status ENUM('pending', 'paid', 'completed', 'cancelled', 'refunded') NOT NULL DEFAULT 'pending',
    payment_method ENUM('cash', 'credit_card', 'debit_card', 'pix', 'other') DEFAULT NULL,
    discount_amount DECIMAL(16, 2) NOT NULL DEFAULT 0,
    /* total_amount DECIMAL(16, 2) NOT NULL DEFAULT 0, IMPLICIT SUM ALL LINES */
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (company_id) REFERENCES Companies(id),
    FOREIGN KEY (branch_id) REFERENCES Branches(id),
    FOREIGN KEY (customer_id) REFERENCES Customers(id),
    FOREIGN KEY (employee_id) REFERENCES Employees(id)
);

-- SALES_LINES TABLE -- Contains the specifics of sales, such as specific products and amounts.
CREATE TABLE Sales_Lines (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sales_order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(16, 2) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (sales_order_id) REFERENCES Sales_Orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(id)
);