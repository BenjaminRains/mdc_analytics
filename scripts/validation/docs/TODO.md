# TODO: Investigate Relationships Between Payment Tables

## Objective
To understand and establish the relationships between the `claimpayment`, `payment`, and `paysplit` tables in the OpenDental database. This will help in accurately linking these tables for comprehensive data analysis.

## Steps to Investigate

1. **Analyze Application Code**
   - Review the source code of the OpenDental system, focusing on sections that handle payments and claims.
   - Identify any logic or functions that process these records and link the tables.

2. **Examine Database Triggers and Stored Procedures**
   - Check for any database triggers or stored procedures that might automate or enforce relationships between these tables.
   - Look for business logic that isn't immediately apparent from the table schemas alone.

3. **Explore Data Patterns**
   - Perform exploratory data analysis to identify patterns or commonalities between records in these tables.
   - Look for matching fields such as `ClinicNum`, `DepositNum`, or others that might suggest a relationship.

4. **Run Sample Queries**
   - Write and execute sample queries to test different hypotheses about how the tables might be linked.
   - Explore whether `DepositNum` or `ClinicNum` provides a meaningful connection between `claimpayment` and `paysplit`.

5. **Check for External Systems**
   - Determine if there are external systems or integrations that might influence how these tables are used.
   - Consider any third-party systems that could introduce additional business rules or data flows.

6. **Review Audit Logs**
   - If available, review audit logs to gain a historical view of how data is entered and modified.
   - Use these logs to identify any clues about the relationships between tables.

## Next Steps
- Document findings and update the `business_logic_fee_process.md` with any new insights.
- Collaborate with domain experts or database administrators to validate findings and refine understanding.
- Develop a strategy for integrating `claimpayment` into the existing queries once relationships are established.

## Notes
- Ensure that any changes or findings are communicated with the team to maintain alignment.
- Consider the impact of any new relationships on existing queries and business processes.

---

This document serves as a guide for investigating and understanding the relationships between key payment-related tables in the OpenDental database. 