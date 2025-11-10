  

ADR-009 Cost Control and Autoscaling

  

  

- Status: Accepted
- Date: 2025-10-23
- Owners: FinOps Lead

  

  

  

Context

  

  

Continuous ingestion and embedding are compute- and storage-intensive. Costs must remain predictable as volume scales.

  

  

Decision

  

  

Apply usage-based scaling with defined thresholds and cost visibility.

  

- Compute:  
    

- Lambda scales on SQS depth.
- Fargate task count tied to queue metrics via Application Auto Scaling.

-   
    
- Storage:  
    

- S3 lifecycle rules offload old data to Glacier.
- DynamoDB on-demand mode for variable load.

-   
    
- Vectors:  
    

- Weaviate replicas scaled based on upsert latency and query load.

-   
    
- Monitoring:  
    

- CloudWatch billing alarms at 75%, 90%, 100% of monthly budget.
- Cost Explorer daily export to S3 for FinOps analysis.

-   
    

  

  

  

Alternatives

  

  

1. Static instance allocation.
2. Hybrid autoscaling with Kubernetes HPA.
3. Cloud cost dashboards only.

  

  

Rejected for inefficiency or lack of automation.

  

  

Consequences

  

  

- Predictable cost envelope.
- Slight cold-start latency at low traffic.
- Requires weekly cost review.

  

  

  

Links

  

  

- infra/modules/autoscaling/
- ops/dashboards/cost.json