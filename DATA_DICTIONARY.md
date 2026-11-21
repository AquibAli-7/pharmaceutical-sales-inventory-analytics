# Data dictionary and accounting rules

All records are synthetic. Dates cover 2024-01-01 through 2025-12-31. Manufacture and expiry dates may fall outside this window. Currency: INR. Quantity unit: pack. No patient data or actual medicine claims.

| File | One row represents | Fields and meanings |
|---|---|---|
| categories.csv | A category | category_id: unique key; category_name: fictional business grouping |
| products.csv | A product | product_id: key; product_name: generic-name-based illustrative SKU label; generic_name; strength; dosage_form; pack_size_units: tablets/capsules per pack; category_id: category reference; manufacturer: fictional manufacturer; unit_of_measure: pack; standard_cost_inr: reference cost, not actual batch cost; list_price_inr: base reference selling price; reorder_point_packs: threshold; target_stock_packs: receipt policy target |
| customers.csv | A customer | customer_id: key; customer_name: fictional label; customer_type: Hospital/Pharmacy/Clinic; contact_person: invented contact name; city, state and region: destination geography |
| suppliers.csv | A supplier | supplier_id: key; supplier_name: fictional label; city; state |
| batches.csv | A received batch | batch_id: key; product_id and supplier_id: references; manufacture_date and expiry_date: batch dates; unit_cost_inr: actual simulated purchase cost per pack |
| stock_receipts.csv | A receipt of one batch | receipt_id: key; receipt_date; batch_id; product_id; quantity_received_packs: positive stock movement |
| sales.csv | A sale line fulfilled from one batch | sales_line_id: logical key, repeated by intentional duplicate errors; sale_date; customer_id: some unknown; product_id; batch_id; quantity_packs: positive units sold; unit_price_inr: before discount; discount_pct: percentage from 0–100 |
| stock_adjustments.csv | An expiry write-off | adjustment_id: key; adjustment_date; product_id; batch_id; adjustment_type: EXPIRY_WRITE_OFF; quantity_change_packs: negative stock movement |
| inventory_month_end.csv | One product's month-end balance | snapshot_date and product_id: composite key; closing_stock_packs: control total after that day's movements |

## Relationships

Categories → products; products → batches and sales; suppliers → batches; customers → sales; batches → receipts, sales, and adjustments. Snapshots reference products. In Power BI, design one unambiguous filter path rather than enabling every possible relationship. A fact table's repeated keys are not dimension duplicates.

## Financial formulas

- Gross line amount = quantity_packs × unit_price_inr.
- Line discount = gross line amount × discount_pct / 100; round to two decimal places per line using a documented consistent rule across tools.
- Net line revenue = gross line amount − line discount.
- Cost of goods sold = quantity_packs × batch unit_cost_inr.
- Gross profit = net sales revenue − cost of goods sold. Excludes stock write-off losses and operating expenses; do not label it net profit.
- Remaining inventory cost value = sum of remaining batch quantities × corresponding batch unit cost.
- Expiry-risk value = remaining eligible quantity × batch cost, for unexpired batches inside the selected expiry window. It is exposure, not realised loss or guaranteed savings.

## Inventory rules

Opening inventory before 2024-01-01 is zero. Opening stock is represented by receipts on 2024-01-01; do not add a second opening balance.

Batch stock as of date D = receipts through D − sales through D + signed adjustments through D.

An expiry write-off occurs at the start of the expiry date. Receipts occur before sales that day. Sales cannot draw expired stock. Daily allocation uses the earliest-expiring eligible batch first. A sales line ID is not an invoice ID: no order-count KPI can be inferred from it.

Monthly stock snapshots are validation totals, not movements. Sum stock across products on one snapshot date; never sum stock across all dates. A daily stock series requires reconstructing movements, not treating monthly snapshots as daily data. Reconstruct batches to value stock and evaluate expiry risk.

No sales returns, tax, transit stock, lead times, lost-demand records, or regional inventory locations are modelled. Observed sales do not establish unmet customer demand. The reorder threshold is a teaching assumption, not an optimised pharmaceutical replenishment rule.

## Cleaning rules to investigate

Keep raw data immutable. Profile first. Resolve exact repeated sales lines using sales_line_id and row equality. Parse ISO dates and DD/MM/YYYY explicitly; avoid ambiguous month/day inference. Remove INR/comma formatting before numeric conversion. Trim and uppercase product keys before foreign-key checks. Standardise display labels. Retain missing customer IDs as unknown (or add a documented unknown dimension member when modelling); do not invent customer identities.

No missing prices, negative quantities, fake product references, or invalid sale dates are intentionally inserted. Such issues should still be checked. Cleaning should not manufacture problems just to increase the cleaning log.

## Version 2 commercial-detail improvements

100 SKUs represent 25 generic medicine names with two illustrative strengths and two pack sizes each. All 12 manufacturer names, 40 customer businesses, customer contacts, and 10 supplier names are invented. Customers cover pharmacies, clinics, and hospitals in 10 Indian cities. No personal contact details are included. Costs scale with pack size; product-specific reorder thresholds and target stocks vary. Wholesale quantities include ordinary and occasional bulk purchases.

The NHS Medicines A–Z (https://www.nhs.uk/medicines/, accessed 16 November 2026) was consulted for recognisable generic naming only. It is not the source of the transactional data, prices, packaging, categories, or commercial assumptions. This is not a clinically validated catalogue or a record of available Indian SKUs.
