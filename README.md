# MarketLedger 📊🛒

[![Download on the App Store](https://img.shields.io/badge/Download_on_the-App_Store-black?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/us/app/marketledger/id6815257619)
[![Android APK](https://img.shields.io/badge/Download-Android_APK-3DDC84?style=for-the-badge&logo=android&logoColor=white)](#-download-android-apk)
[![Flutter](https://img.shields.io/badge/Flutter-3.13+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

**MarketLedger** is a production-grade, offline-first mobile and tablet application engineered for field sales representatives, FMCG wholesale distributors, and retail suppliers. It streamlines rapid order booking, customer shop directories with GPS pinning, and debit/credit ledger tracking with zero cloud dependency.

---

## 📥 Download & Installation

### 🍎 iOS & iPadOS (Official App Store)
MarketLedger is officially available and verified on the Apple App Store for iPhone and iPad:

👉 **[Download MarketLedger on the App Store](https://apps.apple.com/us/app/marketledger/id6815257619)**

* **Compatibility**: Requires iOS 17.0 or later (Optimized for iPhone, iPad Split-View, and Stage Manager).
* **Price**: Free.
* **Privacy**: 100% on-device local storage. Zero personal data collected.

---

### 🤖 Download Android APK

You can install MarketLedger directly onto any Android device using the release APK:

#### Option A: Direct APK Download
1. Download the latest **`app-release.apk`** from the [GitHub Releases](https://github.com/tadianazeemi04/Market_Ledger/releases/tag/v1.0) section (or from the project repository).
2. Transfer or download the APK file directly onto your Android phone or tablet.

#### Option B: Build APK from Source
If you are a developer with Flutter installed:
```bash
# Clone the repository
git clone https://github.com/tadianazeemi04/marketledger.git
cd marketledger

# Install dependencies
flutter pub get

# Build production release APK
flutter build apk --release
```
The compiled APK will be generated at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

#### 📲 How to Install the APK on Android (Step-by-Step):
1. **Locate the File**: Open the **Files** or **Downloads** app on your Android device and tap on `app-release.apk`.
2. **Allow Installation**:
   * If Android displays a prompt saying *"For your security, your phone is not allowed to install unknown apps from this source"*, tap **Settings**.
   * Toggle on **"Allow from this source"** (or **"Install unknown apps"**).
3. **Confirm Install**: Press the back button and tap **Install**.
4. **Launch**: Once installation is complete, tap **Open** to start using MarketLedger immediately!

---

## 🌟 Key Features

### 1. 📊 Interactive Dashboard
- **Salesperson Greeting**: Personalized greeting with live date and active sales route tracking.
- **Real-Time Financial Metrics**:
  - **Today's Orders**: Total bookings taken today.
  - **Total Order Value**: Grand total booked for today.
  - **Advances Collected**: Total cash and digital transfers collected today (in emerald green).
  - **Pending Balance**: Outstanding balances across active orders (in amber accent).
- **Recent Orders Feed**: Quick-view cards with shop name, owner, amount, payment status, and order status.
- **Quick Action Bar**: One-tap shortcuts to register a shop, browse the catalog, or take new orders.

### 2. 🏪 Customers & Retail Shops Directory
- **Searchable Directory**: Instant sub-millisecond search across shop names, owner names, market areas, and phone numbers.
- **Shop Profile & Lifetime Stats**: Tracks lifetime orders, total spend, last order date, and outstanding dues.
- **1-Tap GPS Location Pinning**: Captures high-accuracy GPS coordinates during store visits to optimize delivery dispatch routes.
- **Direct Phone Dialing**: One-tap phone call and WhatsApp contact integration.

### 3. 📦 Wholesale Product Catalog & Multi-Unit Pricing
- **Flexible Packaging Units**: Full support for Carton, Box, Tin, Bag, Pack, kg, and individual pieces.
- **Real-Time Deal Overrides**: Supports unit price overrides for negotiated wholesale deals.
- **Inline Product Creation**: Sales reps can create unlisted products directly inside the order builder without losing order context.

### 4. 📝 Rapid Order Booking Engine
- **Human-Readable Order ID**: Auto-generates clean sequential IDs: `ML-YYYYMMDD-XXX`.
- **Multi-Line Item Manager**: Quantity steppers (`+`/`-`), line-item discounts, and auto-computed line totals.
- **Order Financials**:
  $$\text{Grand Total} = \text{Subtotal} - \text{Order Discount} + \text{Delivery Charges}$$
  $$\text{Remaining Balance} = \text{Grand Total} - \text{Advance Payment}$$
- **Payment Methods**: Cash, Bank Transfer, Online/Mobile Wallet, Cheque, and Custom Reference numbers.
- **Order Status Workflow**: `Draft`, `Confirmed`, `Processing`, `Delivered`, `Cancelled`.

### 5. 💳 Multi-Payment Ledger & Balance Tracking
- Tracks multiple payment installments per order with date, reference codes, and notes.
- Atomic balance recalculation with instant `Unpaid`, `Partial`, or `Paid` status updates.

### 6. 🧾 Instant Digital Receipts & Sharing
- Generates clean, itemized digital receipts formatted for WhatsApp, SMS, AirDrop, and mobile thermal printers via native system Share Sheets (`share_plus`).

### 7. 🏢 Multi-Account & Company Profile Switching
- Seamlessly configure and switch between multiple distributor agencies or business routes in Settings with zero data conflict.

---

## 🎨 Brand & Design System

MarketLedger strictly adheres to an accessible, high-contrast Material 3 palette:

| Color Token | Hex Code | Purpose |
|---|---|---|
| **Primary Navy** | `#12355B` | App bars, primary action buttons, active navigation |
| **Deep Navy** | `#0B1F33` | Headings, card titles, prominent typography |
| **Emerald Green** | `#168A5B` | Paid status, delivered orders, cash collected |
| **Amber Accent** | `#F2A93B` | Pending balances, partial settlements, processing orders |
| **Soft Background** | `#F6F8FB` | Scaffold background and subtle card fills |
| **Card Surface** | `#FFFFFF` | Elevated cards, dialogs, bottom sheets |
| **Primary Text** | `#17212B` | High-contrast body copy and form labels |
| **Secondary Text** | `#667085` | Subtitles, timestamps, and secondary metadata |
| **Error / Alert** | `#D32F2F` | Unpaid dues, cancellations, validation alerts |

---

## 🏗️ Architecture & Folder Structure

MarketLedger follows a clean, feature-first modular architecture:

```text
lib/
├── Logo/                             # Brand assets & vector logos
├── core/
│   ├── constants/enums.dart          # OrderStatus, PaymentStatus, PaymentMethod
│   ├── database/database_helper.dart # SQLite initialization, migrations & seed data
│   ├── theme/                        # AppColors & Material 3 typography
│   └── utils/                        # CurrencyFormatter & DateFormatter
├── features/
│   ├── customers/                    # Shop directory, forms, and GPS pinning
│   ├── dashboard/                    # Real-time metrics & recent orders
│   ├── orders/                       # Order builder, details & balance calculation
│   ├── payments/                     # Multi-payment installment ledger
│   ├── products/                     # Product catalog & multi-unit pricing
│   ├── receipt/                      # Digital receipt generator & share sheet
│   └── settings/                     # Multi-account profiles & data export
└── main.dart                         # Responsive root shell & navigation
```

---

## 🧪 Automated Testing & Quality Assurance

MarketLedger includes a comprehensive test suite of **46+ unit, widget, and layout tests**:
- **Financial Computations**: Line items, discounts, delivery fees, and edge-case decimal precision.
- **SQLite Serialization**: Complete round-trip model serialization and schema integrity.
- **Responsive Layout Verification**: Tests iPadOS landscape/portrait split-views (`820x1180` and `380x1400`) ensuring **zero RenderFlex overflows**.
- **Multi-Account Concurrency**: Validates account switching, duplicate prevention, and clean data isolation.

To run the test suite:
```bash
flutter test
```

---

## 🔗 Useful Links & Support

* 🍎 **App Store Listing**: [MarketLedger on the App Store](https://apps.apple.com/us/app/marketledger/id6815257619)
* 🔒 **Privacy Policy**: [Read Privacy Policy](https://sites.google.com/view/marketledger/privacy-police)
* 🛟 **Support & Help Center**: [Visit Support Center](https://sites.google.com/view/marketledger/support)
* 📬 **Developer Contact**: Efe KOCA ([efekkkocc@gmail.com](mailto:efekkkocc@gmail.com))

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
