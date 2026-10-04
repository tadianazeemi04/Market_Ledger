# MarketLedger Mobile App 📱🛒

**MarketLedger** is a production-quality, offline-first Flutter mobile application crafted for field salespeople collecting wholesale orders from local retail shops and busy market bazaars. 

Built with **Flutter**, **Material 3 UI**, **SQLite (`sqflite`)**, and **Riverpod** state management, MarketLedger operates completely offline without requiring sign-in or an internet connection.

---

## 🌟 Key Features

### 1. 📊 Interactive Dashboard
- **Salesperson Greeting**: Personalized greeting with live date display (`Tuesday, 22 Sep 2026`).
- **4 Key Business Metrics**:
  - **Today's Orders**: Total bookings taken today.
  - **Total Order Value**: Grand total booked for today.
  - **Advances Collected**: Total cash and digital transfers collected today (in emerald green).
  - **Pending Balance**: Outstanding balances across active orders (in amber accent).
- **Recent Orders Feed**: Quick-view cards with shop name, owner, amount, payment status, and order status.
- **Quick Action Bar**: Fast shortcuts to register a shop, browse product catalog, or create orders.
- **Floating Action Button**: High-visibility `+ New Order` button.

### 2. 🏪 Customers & Retail Shops
- **Searchable Shop Directory**: Instant search across shop name, owner name, market area, and phone number.
- **Shop Profile & Order Stats**: Displays lifetime orders placed, total spend, last order date, and outstanding balance.
- **Shop Registration Form**:
  - Shop name (required) & Owner name (required).
  - Phone / WhatsApp with one-tap copy.
  - Market area & full street address.
  - **GPS Location Capture**: Captures device GPS coordinates with graceful permission handling (denied, disabled, permanently denied).
  - Wholesale notes & delivery preferences.
- **Customer Detail Screen**: Complete profile information, GPS badge, lifetime statistics, and full chronological past-order history.

### 3. 📦 Wholesale Product Catalog
- **Realistic Seed Catalog**: Pre-populated with typical high-turnover wholesale products (Cooking Oil 5L, Basmati Rice 25kg, Sugar 50kg, Tea 900g, Chakki Atta 20kg, Ghee, Spices, Detergents, Mineral Water).
- **Product Details**: Name, SKU/Code, Unit (Tin, Bag, Carton, Box, Pack, kg, pcs), Selling Price, and Active/Inactive toggle.
- **Quick Inline Product Creation**: If a salesman encounters an unlisted item in the field, they can create and add it directly inside the order builder without losing their order context!

### 4. 📝 Create & Edit Order Builder
- **Customer Selector**: Choose existing customer with search or click `+ Add New` to create one inline.
- **Human-Readable Order ID**: Auto-generated format: `ML-YYYYMMDD-XXX` (e.g., `ML-20260922-001`).
- **Multi-Line Item Manager**:
  - Add products with quantity steppers (`+` / `-`).
  - Unit price override support for negotiated deals.
  - Optional item-level discount and real-time line total calculation.
- **Order Financials**:
  - Subtotal calculation.
  - Overall order discount.
  - Delivery charge.
  - Grand Total = `Subtotal - Discount + Delivery`.
  - Advance payment input.
  - Real-time Remaining Balance = `Grand Total - Advance Payment`.
- **Payment Method Choices**: Cash, Bank Transfer, JazzCash/EasyPaisa, Cheque, Other (with optional transaction reference #).
- **Auto-Calculated Payment Status**: Automatically sets `Unpaid`, `Partial`, or `Paid`.
- **Order Status Choices**: `Draft`, `Confirmed`, `Processing`, `Delivered`, `Cancelled`.
- **Dual Actions**: "Save as Draft" vs. "Confirm & Save Order".

### 5. 🔍 Filterable Order List & Order Details
- **Multi-Dimensional Filters**:
  - Text search by order number, shop name, owner name, market area.
  - Order status chips (`Draft`, `Confirmed`, `Processing`, `Delivered`, `Cancelled`).
  - Payment status chips (`Unpaid`, `Partial`, `Paid`).
  - Date period filters (`All Time`, `Today`, `This Week`, `This Month`).
- **Detailed Order View**:
  - Header with order number, booking timestamp, delivery date, and colored status chips.
  - Retailer profile card with phone, address, and GPS coordinates.
  - Itemized product list with quantities, units, and line totals.
  - Complete financial breakdown (subtotal, discounts, delivery, grand total, balance).
  - Activity timestamps (`Created At`, `Updated At`).
  - Quick action to **Mark Delivered**.
  - **Record Payment** action that adds a payment entry and atomically recalculates the balance.

### 6. 💳 Multi-Payment Ledger
- Each order tracks multiple payment installments.
- Fields: Amount, Payment Method, Date/Time, Reference Number (Cheque / TID), Note.
- Instant balance reduction and status update upon recording a payment.

### 7. 📄 Shareable Receipt & Order Summary
- Generates a neat, text-based receipt summary formatted for thermal printers, SMS, and WhatsApp:
  - MarketLedger header
  - Order number and timestamps
  - Customer / shop details
  - Itemized product breakdown
  - Subtotal, discounts, delivery, grand total, advance paid, and balance due
  - Payment ledger history
  - Sales representative name & company name
- **Actions**: One-tap **Copy Text to Clipboard** and native system **Share Sheet** (`share_plus`).

### 8. ⚙️ Settings & Data Export
- Distributor / Company name configuration.
- Sales representative profile (Name & Phone).
- Default currency selector (PKR `Rs.`, USD `$`, EUR `€`, GBP `£`, AED `AED`, SAR `SAR`, INR `₹`).
- **Data Export**:
  - Export Orders as CSV.
  - Export Customers & Coordinates as CSV.
  - Export Full Database as JSON.
- **Reset Demo Data**: Restore sample products, customers, and orders with confirmation.

---

## 🎨 Brand & Visual Design System

MarketLedger strictly adheres to the approved brand palette:

| Color Token | Hex Code | Purpose |
|---|---|---|
| **Primary Navy** | `#12355B` | App bars, primary action buttons, active navigation items |
| **Deep Navy** | `#0B1F33` | Headings, card titles, prominent text |
| **Emerald Green** | `#168A5B` | Paid payment status, delivered orders, cash collected |
| **Amber Accent** | `#F2A93B` | Pending balances, partial payments, processing orders |
| **Soft Background** | `#F6F8FB` | Scaffold background and subtle card fills |
| **White** | `#FFFFFF` | Card surfaces, dialogs, bottom sheets |
| **Primary Text** | `#17212B` | Body copy and field labels |
| **Secondary Text** | `#667085` | Subtitles, helper text, and secondary details |
| **Error / Alert** | `#D32F2F` | Unpaid dues, cancelled orders, deletions |

---

## 🏗️ Architecture & Folder Structure

MarketLedger follows a clean, feature-first modular architecture:

```
lib/
├── Logo/
│   └── MarketLedgerLogo.png          # High-resolution brand logo
├── core/
│   ├── constants/
│   │   └── enums.dart                # OrderStatus, PaymentStatus, PaymentMethod
│   ├── database/
│   │   └── database_helper.dart      # SQLite initialization, schema, indexing & seed data
│   ├── theme/
│   │   ├── app_colors.dart           # Brand color tokens
│   │   └── app_theme.dart            # Material 3 ThemeData & typography
│   ├── utils/
│   │   ├── currency_formatter.dart   # Multi-currency formatting
│   │   └── date_formatter.dart       # Relative & localized date formatting
│   └── widgets/
│       ├── confirm_dialog.dart       # Reusable alert modal
│       ├── custom_text_field.dart    # Standardized high-contrast text inputs
│       ├── empty_state.dart          # Empty list & search states
│       └── status_chips.dart         # Status & Payment badges
├── features/
│   ├── customers/
│   │   ├── data/customer_repository.dart
│   │   ├── domain/customer_model.dart
│   │   └── presentation/
│   │       ├── customer_detail_screen.dart
│   │       ├── customer_form_screen.dart   # GPS location capture
│   │       ├── customer_providers.dart
│   │       └── customers_screen.dart
│   ├── dashboard/
│   │   └── presentation/
│   │       ├── dashboard_provider.dart
│   │       └── dashboard_screen.dart
│   ├── orders/
│   │   ├── data/order_repository.dart
│   │   ├── domain/
│   │   │   ├── order_item_model.dart
│   │   │   └── order_model.dart
│   │   └── presentation/
│   │       ├── create_order_screen.dart    # Multi-item order builder
│   │       ├── order_detail_screen.dart    # Financial breakdown & actions
│   │       ├── order_providers.dart
│   │       ├── orders_screen.dart
│   │       └── record_payment_dialog.dart  # Instant balance recalculation
│   ├── payments/
│   │   ├── data/payment_repository.dart
│   │   ├── domain/payment_model.dart
│   │   └── presentation/payment_providers.dart
│   ├── products/
│   │   ├── data/product_repository.dart
│   │   ├── domain/product_model.dart
│   │   └── presentation/
│   │       ├── product_providers.dart
│   │       └── products_screen.dart
│   ├── receipt/
│   │   ├── presentation/receipt_dialog.dart
│   │   └── services/receipt_service.dart   # Text formatter & share sheet
│   └── settings/
│       ├── data/settings_repository.dart
│       ├── domain/settings_model.dart
│       └── presentation/
│           ├── settings_provider.dart
│           └── settings_screen.dart
└── main.dart                               # Root widget & 5-tab NavigationBar
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+ or Flutter 3.47+)
- Android Studio / VS Code with Flutter extension
- An Android device / emulator or iOS simulator

### Installation & Run

1. Clone or navigate to the repository directory:
   ```bash
   cd marketLedger
   ```

2. Fetch all dependencies:
   ```bash
   flutter pub get
   ```

3. Run static analysis (verifies 0 lint errors):
   ```bash
   flutter analyze
   ```

4. Run the automated test suite:
   ```bash
   flutter test
   ```

5. Launch the application:
   ```bash
   flutter run
   ```

---

## 🧪 Testing

The test suite in `test/` validates:
- **Order Financial Calculations**: Multi-item line totals, overall discounts, delivery charges, advance adjustments, and boundary tests for payment status calculation.
- **Data Model Serialization**: SQLite map conversion and round-trip fidelity for Customers, Products, Orders, Payments, and AppSettings.
- **Receipt Summary Engine**: Verifies that generated receipts contain complete customer info, itemized records, correct balances, and sales rep details.
- **Root Navigation Smoke Test**: Ensures all 5 navigation tabs render properly within `ProviderScope`.
