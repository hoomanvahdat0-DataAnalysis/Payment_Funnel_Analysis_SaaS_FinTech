# Payment-Funnel-Analysis-SaaS-FinTech

## Executive Summary:
Fewer customers are completing their orders than we'd like to see, and we set out to find out why. I tracked every order from the moment a customer starts checkout to the moment they finish, and found that most of the lost revenue isn't happening where we expected — it's not customers giving up while entering payment details. It's happening after payment goes through, when a large share of orders never get marked as complete. I Recommend these few adjustments:
1. Prioritize the "payment succeeded but order didn't finalize" bug — this is a technical issue, not a customer experience gap, and it's responsible for our largest single revenue loss.
2. Address failed and stuck payments — declined cards, timeouts, and fraud checks are driving a second major drop-off point.
3. Pause any checkout screen redesign — that step is already performing well, so resources are better directed elsewhere.
4. Manage cancelations as a separate initiative — customers are leaving because they don't find enough value, not because of cost, so retention efforts should focus on onboarding rather than pricing or discounts.
   
## Business Problem:
Completed orders are directly tied to revenue for this Business. Product and sales stakeholders noticed a lower-than-expected conversion rate (users who start an order vs. users who complete it). This project identifies **where** in the workflow users fall out and **which fixes** would recover the most revenue.

![Data Model](https://github.com/hoomanv3xo/Payment-Funnel-Analysis-SaaS_FinTech/blob/main/data%20model.png)
![Data Model](https://github.com/hoomanv3xo/Payment-Funnel-Analysis-SaaS_FinTech/blob/main/payment%20funnel%20stages.png)

## Methodology:
1. **EDA**
2. **SQL** — extracts, cleans, and transforms raw order/payment/customer data into a funnel-ready fact table.
3. **Python** — builds the stage-by-stage funnel, visualizes drop-off, and runs a Monte Carlo simulation estimating the revenue impact of improving conversion at each step.
4. **Dashboard** — an HTML dashboard (no Power BI required) presenting the funnel, drop-off, revenue-at-risk, and cancelation reasons in one view.

   
## Skills:
1. SQL: CTEs, CASE, Union, View creation
2. Data Visualization
3. Data Wrangling
4. Data Cleaning
5. Data Science Notebook
6. Snowflake Data warehouse
7. Python

## Results and Business Recommendations:
1. Pattern held consistently across the dataset: overall conversion lands around 33–35% in every version.

2. Data suggested:
- Sample & synthetic data pointed to **PaymentWidgetOpened→Entered** as the top leak (~33% drop) — this turned out to be a healthier step in the real data (only ~20% drop).
- The **real** top leaks are **PaymentSubmitted→Success (27% drop)** and **PaymentSuccess→Complete (37% drop)** — the latter is especially notable because payment already succeeded at that point, pointing to a technical/confirmation bug (webhook, status-sync, or redirect failure) rather than a user-hesitation problem.

![Data Model](https://github.com/hoomanv3xo/Payment-Funnel-Analysis-SaaS_FinTech/blob/main/dropoff_chart_live.png)
![Data Model](https://github.com/hoomanv3xo/Payment-Funnel-Analysis-SaaS_FinTech/blob/main/funnel_chart_live.png)

## Next Steps:
1. Investigate the Submitted→Success gap as a payments-operations issue — likely causes include card declines, gateway timeouts, or fraud verification failures.
2. Treat Success→Complete as an engineering bug, not a UX fix — payment already succeeds at this point, so the order simply isn't finalizing.
3. Handle post-purchase churn as a separate workstream from the order funnel — since "not useful" outranks "expensive" as a cancelation reason, this points to an onboarding/activation gap rather than a pricing problem.
