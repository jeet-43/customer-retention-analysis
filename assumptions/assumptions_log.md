# Assumptions Log

Every cleaning decision made in `01_cleaning.ipynb`, in the order it was applied, along with how many rows it affected.

Starting row count: 1,067,371

## Removed non-product StockCodes (POST, DOT, M, D, BANK CHARGES, etc)
- Rows affected: 5,859
- Rows remaining after this step: 1,061,512

## Removed cancellation invoices (Invoice starts with 'C')
- Rows affected: 18,290
- Rows remaining after this step: 1,043,222
- Note: this runs after the non-product StockCode removal above, so a cancelled postage charge
  or fee line is already gone by this point and never counted here. The 18,290 figure is
  cancelled product lines only, not every cancellation that happened in the raw data. Worth a
  one-line caveat if a "total cancelled value" number ever shows up on a dashboard.

## Removed negative-quantity rows without a cancellation invoice (stock write-offs, damages, lost stock)
- Rows affected: 3,454
- Rows remaining after this step: 1,039,768

## Removed rows with Price <= 0 (free samples, price entry errors)
- Rows affected: 2,718
- Rows remaining after this step: 1,037,050

## Removed exact duplicate rows
- Rows affected: 33,664
- Rows remaining after this step: 1,003,386

## Set aside rows with no Customer ID into a separate guest-orders table (kept for revenue/product-level work, excluded from customer-level work)
- Rows affected: 226,794
- Rows remaining after this step: 776,592

## Final result
- Full cleaned table: 1,003,386 rows
- Customer-level table (used for RFM, cohort, churn): 776,592 rows
- Guest-orders table (no Customer ID, kept for revenue/product analysis only): 226,794 rows
- Cancellations table (kept separately, not merged back in): 18,290 rows

---

# Phase 4 additions

Decisions made in `02_eda.ipynb` and `03_rfm_churn_cohort.ipynb`, on top of the cleaning
decisions above.

## Snapshot date for recency
- Used 2011-12-10 (one day after the last invoice in the dataset) as "today" for every
  recency calculation. Anything dated later would be meaningless since there's no data past
  2011-12-09.

## Churn cutoff: 90 days of inactivity
- Checked the actual gap between consecutive orders for every repeat customer before picking
  a number. Median gap: 25 days. 75th percentile: 62 days. 90th percentile: 135 days.
- Went with 90 days since it sits past where most normal reorder behavior happens (above the
  75th percentile) without flagging customers who are still within a plausible slower buying
  rhythm (below the 90th percentile). Also just an easy number to explain to a stakeholder.
- Result: 50.7% of customers (2,967 of 5,852) are past this cutoff as of the snapshot date.
  Flagged in the notebook that the most recent 2 to 3 months are censored, meaning there
  hasn't been enough time yet to know if those customers will reorder, so the true churn rate
  for those months reads artificially low and shouldn't be compared directly to earlier months.

## RFM scoring: qcut with rank(method='first') on frequency
- Plain quintile cuts on frequency failed because too many customers share the same order
  count (a lot of people at exactly 1, 2, or 3 orders), so there weren't 5 distinct bin edges
  to split on. Ranked the raw frequency values first to break ties, then quintile-cut the
  ranks instead. Doesn't change what the score means, just makes the cut possible.

## RFM segment rules
- Built a simplified 8-segment rule set (Champions, Loyal Customers, New Customers, Potential
  Loyalists, At Risk, Cant Lose Them, Lost, Needs Attention) based on R/F/M score combinations,
  rather than using a finer-grained industry template. With 5,852 customers, a more granular
  rule set would produce segments too small to be useful to a stakeholder.
- First version of the rule set had At Risk requiring F score >= 4 and Lost requiring M score
  <= 2. That left two combinations unhandled (R<=2 with F score exactly 3, and R<=2/F<=2 with M
  score exactly 3), and both defaulted into Needs Attention, which is why that segment came out
  82.1% churned even though recency wasn't part of its definition. Fixed by widening At Risk to
  F>=3 and Lost to M<=3, since both unhandled slivers already had R<=2 and behaved like the
  other gone-quiet segments. Needs Attention is now only R==3 with F<=2, customers with
  middling recency who never built up frequency, and it comes out at 51.7% churned, which fits
  a genuine watch-list group instead of a leftover bucket.
- Segment sizes after the fix: Lost 24.8%, Champions 22.0%, At Risk 14.1%, Potential Loyalists
  13.2%, Loyal Customers 10.6%, New Customers 7.7%, Needs Attention 6.5%, Cant Lose Them 1.0%.

## Cohort retention: customer-level table only, guests excluded
- Same reasoning as the customer-level split in Phase 2. A cohort needs to track the same
  customer across multiple months, which is impossible for a guest order with no Customer ID.
- This means cohort retention numbers describe about 87% of total revenue (identified customers
  only), not the full business. `02_eda.ipynb` computed this directly: guest orders are 22.0% of
  rows but only 13.1% of revenue, so identified customers account for the other 86.9%, rounded
  to 87%. Worth a callout in the executive summary so the retention percentages don't get read
  as covering 100% of the customer base, and worth using the correct 87% figure rather than the
  "roughly three-quarters" estimate that was floating around earlier in the project, since that
  understated how much of the business the retention numbers actually cover.

## Primary country per customer
- A customer's primary country is picked by which country shows up most often, but this is
  counted per invoice, not per line item. A customer with one large multi-line order from one
  country and several small orders from another should be tagged by where most of their orders
  came from, not by whichever country happened to have the most product lines on a single
  invoice. Only affected 3 of 5,852 customers when checked against the line-item version, but
  it's the more defensible method going forward.

## Final result, Phase 4
- `datasets/derived/customer_segments.csv`: 5,852 rows, one per identified customer, with RFM
  scores, segment label, churn flag, cohort month, and primary country. Feeds directly into
  the Power BI customer dimension table in Phase 5.

---

# Fixes applied after review

A few issues surfaced going back through the notebooks before moving into Power BI, listed here
so the log stays an honest record of what changed and why.

- **Folder path mismatch**: `01_data_cleaning.ipynb` originally saved output to `../data/cleaned/`
  while every notebook after it read from `../datasets/cleaned/`. Updated the cleaning notebook
  to save to `../datasets/cleaned/` and `../datasets/derived/` so the folder names match the
  actual repo structure and the notebooks run in order without a path error.
- **RFM segment rule gap**: covered above under "RFM segment rules". Needs Attention went from a
  churned-leaning catch-all (82.1% churned, 1,030 customers) to a properly scoped mid-recency,
  low-frequency group (51.7% churned, 381 customers).
- **Primary country method**: covered above. Switched from line-item weighting to invoice
  weighting.
- **Cancellation scope**: covered above under the cancellation removal step. Added a caveat that
  the cancellations table only reflects product-line cancellations, not fees or postage.
- `customer_segments.csv` was regenerated with the segment and country fixes applied. Row count
  is unchanged at 5,852, only the `Segment` labels and 3 `Country` values shifted.
- **Revenue share for identified customers**: this log and `problem_statement.pdf` both said
  "roughly three-quarters" of revenue is traceable to a named customer. `02_eda.ipynb` had
  already computed the real number correctly at 87%, the "three-quarters" line elsewhere in the
  project just never got updated to match. Corrected the wording here. The PDF cannot be edited
  directly since the source design file isn't part of this project, see the note in the chat
  reply for what to do about that one.
- **Cancellation query sign**: the side query in `02_business_queries.sql` summed
  `Quantity * Price` directly, which returns a negative number since cancellation quantities are
  negative, so the query labeled it `cancelled_value` without saying it was a negative amount.
  Wrapped it in `ABS()` so the result reads as a positive lost-revenue figure like a stakeholder
  would expect, and added its result to `query_results.md` since it had never actually been run
  and recorded there. Cancelled value: 726,611.45 across 7,410 cancellation invoices.
