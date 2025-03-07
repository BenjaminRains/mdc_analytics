# Prepayment Allocation Procedures
## Best Practices for Dental Practice Management

Based on our analysis of unallocated income data, we've identified approximately $65,000 in unallocated prepayments across 168 patient accounts. This document outlines recommendations for developing better allocation procedures to ensure prepayments are promptly allocated to providers and procedures.

## Executive Summary

The analysis revealed:
- 168 guarantors with unallocated credits totaling $65,299.65
- Average credit of $388.69 per guarantor (median of $37.20)
- Significant concentration in a few high-value accounts
- Prepayments represent 94% of unallocated credits
- Most credits occur in accounts with 10-20 transactions

## 1. Update Intake Processes

### Capture Intent at Collection
- When collecting prepayments, immediately document:
  - Specific planned procedures
  - Provider(s) who will perform the work
  - Anticipated treatment date(s)
  - Reason for prepayment (treatment plan, payment plan, etc.)

### Create Standardized Documentation
- Develop a prepayment form that includes:
  - Treatment plan reference number
  - Specific procedures being prepaid (procedure codes)
  - Provider assignment
  - Expected service date(s)
  - Patient acknowledgment signature

### Patient Communication
- Clearly explain to patients:
  - How their prepayment will be applied
  - When it will be applied
  - What happens if treatment changes
  - Refund policy for unused prepayments

## 2. Establish Clear Staff Protocols

### Front Desk Training
- Train front desk and administrative staff to:
  - Never accept prepayments without treatment plan documentation
  - Properly code payments at the time of receipt
  - Use consistent naming conventions for prepayment types
  - Understand the implications of unallocated funds

### Daily Reconciliation Process
- Implement daily review of all payments:
  - Flag any payment splits with ProvNum = 0 or ProcNum = 0
  - Require same-day resolution when possible
  - Escalate unresolved items to office manager
  - Document reason for any intentionally unallocated funds

### Role-Based Responsibilities
- **Front Desk**: Collect payment and allocation intent
- **Billing Specialist**: Verify proper allocation of all new payments
- **Financial Coordinator**: Weekly review of unallocated amounts
- **Office Manager**: Oversee monthly audit of all unallocated funds

## 3. Implement Technical Solutions

### Software Configuration
- Configure practice management system to:
  - Warn when creating unallocated prepayments
  - Require reason codes for unallocated payments
  - Set up automatic allocation rules where possible
  - Flag accounts with unallocated funds over 30 days old

### Regular Reports
- Generate and review the following reports:
  - **Daily**: New unallocated prepayments
  - **Weekly**: Aging report of all unallocated funds
  - **Monthly**: Guarantors with highest unallocated balances
  - **Quarterly**: Trend analysis of unallocated funds

### Automation Opportunities
- Implement automated alerts for:
  - Unallocated funds over 30/60/90 days
  - Accounts with unallocated funds exceeding $500
  - Completed procedures with available unallocated funds
  - Patients with upcoming appointments who have unallocated funds

## 4. Establish a Formal Allocation Workflow

1. **Initial Collection**: 
   - Front desk collects payment and allocation intent
   - Documents in patient record
   - Tags with appropriate allocation codes

2. **Same-Day Review**: 
   - Billing specialist verifies all new payments have proper allocation
   - Resolves any missing information
   - Updates practice management system

3. **Weekly Audit**: 
   - Financial coordinator reviews any unallocated amounts
   - Prioritizes based on amount and age
   - Takes action on high-priority items

4. **Monthly Cleanup**: 
   - Comprehensive review of all accounts with unallocated funds
   - Updates allocation based on completed procedures
   - Identifies accounts requiring patient contact

5. **Patient Communication**: 
   - Contact patients with aging credits to determine allocation
   - Document all communication attempts
   - Establish next steps for resolution

## 5. Address Provider Income Transfer Issues

### Identify Root Causes
- Conduct analysis to determine why income transfers between providers are occurring:
  - Are payments being allocated to default providers instead of treating providers?
  - Do front desk staff understand how to properly assign providers at payment entry?
  - Are there system configuration issues that lead to incorrect provider assignment?
  - Are there specific procedure types or payment methods more prone to allocation issues?

### Standardize Income Transfer Documentation
- Create a formal protocol for necessary income transfers:
  - Develop a standard note format (e.g., "Income transfer: FROM [provider] TO [provider] for [procedure]")
  - Require documentation of the reason for each transfer
  - Mandate supervisor approval for transfers above a certain threshold
  - Maintain consistent staff initials/identifiers in notes

### Implement Provider Assignment Validation
- Add validation steps during payment processing:
  - Verify provider assignment against appointment schedule and procedure history
  - Create alerts when payments are allocated to default or unassigned providers
  - Implement a secondary review for large payments (over $1,000)
  - Add confirmation step when allocating to high-volume providers

### Provider-Specific Training
- Develop targeted training on provider allocation:
  - Train staff on proper provider allocation at point of payment entry
  - Create quick reference guides for payment-to-provider workflows
  - Conduct periodic provider allocation audits and share results with staff
  - Hold dedicated training sessions for staff members who frequently make allocation errors

### System Enhancements for Provider Allocation
- Customize OpenDental to prevent allocation issues:
  - Set up mandatory provider field for all payment entries
  - Create a provider transfer tool with proper audit tracking
  - Develop reports identifying payments without provider allocation
  - Implement validation rules against scheduled providers

### Monitoring and Analytics
- Track provider allocation metrics:
  - Volume and value of income transfers by staff member, provider, and procedure type
  - Trends in allocation errors and corrections
  - Time lag between initial payment and corrective transfers
  - Financial impact of allocation issues on provider production reports

## 6. Create Resolution Procedures for Existing Credits

### Prioritization Strategy
- **Amount-Based**: Start with accounts having the largest credits (top 15 guarantors)
- **Age-Based**: Address older credits first, especially those over 90 days
- **Activity-Based**: Prioritize patients with upcoming appointments
- **Transaction-Based**: Focus on accounts with multiple transactions (10-20 range)

### Documentation Requirements
- For each resolved credit:
  - Document allocation decision and reasoning
  - Note who made the decision and when
  - Record patient communication if applicable
  - Maintain audit trail of all changes

### Patient Notification
- For significant unallocated balances:
  - Send formal written notification
  - Explain credit balance and proposed allocation
  - Provide options (allocate to specific procedures, maintain as credit, refund)
  - Request response within 30 days

## 7. Establish Ongoing Monitoring

### Key Performance Indicators
- Track and report on:
  - Total dollar amount of unallocated funds
  - Percentage of payments left unallocated daily
  - Average age of unallocated funds
  - Resolution rate for identified unallocated funds
  - Frequency and volume of provider income transfers

### Regular Review Meetings
- **Weekly**: Billing team reviews new unallocated funds
- **Monthly**: Financial review with metrics on allocation success
- **Quarterly**: Process improvement discussions based on trends

### Continuous Improvement
- Review KPIs to identify:
  - Common reasons for unallocated payments
  - Staff members who may need additional training
  - Process bottlenecks affecting allocation
  - System configuration changes needed

## 8. Implement Safeguards for Special Cases

### Insurance Overpayments
- Create separate tracking and handling for insurance overpayments
- Develop procedures for timely refunds to insurance companies
- Document all communications with insurance providers

### Treatment Plan Changes
- Establish protocol for reallocating funds when:
  - Treatment plans change
  - Procedures are canceled
  - Different providers perform the work
  - Treatment costs differ from estimates

### Patient Refunds
- Create clear criteria for:
  - When to issue refunds rather than maintaining credits
  - Required documentation for refund processing
  - Approval process for refunds over certain amounts
  - Timing expectations for refund processing

### Provider Transitions
- Develop procedures for handling provider allocation when:
  - Providers leave the practice
  - New providers join the practice
  - Patients transfer between providers
  - Substitute providers perform procedures

## Implementation Timeline

| Phase | Timeframe | Key Activities |
|-------|-----------|---------------|
| 1: Assessment | Weeks 1-2 | Review current processes, identify gaps, establish baseline metrics |
| 2: Process Design | Weeks 3-4 | Develop new procedures, create documentation templates |
| 3: Staff Training | Weeks 5-6 | Train all staff on new procedures, roles, and expectations |
| 4: Resolution Blitz | Weeks 7-10 | Focused effort to resolve existing unallocated credits |
| 5: Provider Allocation Focus | Weeks 11-12 | Dedicated effort to address provider income transfer issues |
| 6: Full Implementation | Week 13+ | New procedures fully operational, regular review cycle begins |

## Expected Outcomes

By implementing these procedures, the practice should achieve:

1. Reduction in unallocated prepayments by 80% within 3 months
2. Average age of unallocated funds under 30 days
3. Clearer patient understanding of how their prepayments are managed
4. Improved financial reporting accuracy
5. Reduced staff time spent on payment reconciliation
6. Better visibility into true production and collection metrics
7. 90% reduction in provider income transfers within 3 months
8. Accurate provider production reporting leading to improved compensation calculations

## Conclusion

Implementing structured prepayment allocation procedures will not only reduce the current backlog of unallocated funds but also prevent future accumulation. This will improve financial accuracy, enhance patient satisfaction, and reduce administrative burden on staff. The added focus on provider allocation will ensure proper income attribution, eliminating the need for manual income transfers and improving the accuracy of provider production metrics.

**Recommended next steps:**
1. Review this document with the leadership team
2. Assign an implementation leader
3. Establish baseline metrics
4. Begin staff training on new procedures
5. Schedule follow-up analysis in 90 days 