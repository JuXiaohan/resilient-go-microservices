# Microservices Scaling and Load Balancing Guide

## Overview

This guide explains how scaling and load balancing work in your microservices architecture and how to automate these processes.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              External Traffic                               │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────────────────┐
│                           NGINX Ingress Controller                         │
│                              (Load Balancer)                               │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   Broker Service│    │ Authentication  │    │  Logger Service │        │
│  │   (2-10 pods)   │    │   Service       │    │   (2-6 pods)    │        │
│  │   Port: 8080    │    │   (2-8 pods)    │    │   Port: 80      │        │
│  │   [HPA Enabled] │    │   Port: 80      │    │   [HPA Enabled] │        │
│  │   [HPA Enabled] │    │   [HPA Enabled] │    │   [HPA Enabled] │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│           │                       │                       │                │
│           ▼                       ▼                       ▼                │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   PostgreSQL    │    │   PostgreSQL    │    │   MongoDB       │        │
│  │   (1 replica)   │    │   (1 replica)   │    │   (1 replica)   │        │
│  │   Port: 5432    │    │   Port: 5432    │    │   Port: 27017   │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Scaling Strategies

### 1. Horizontal Pod Autoscaler (HPA)

**What it does:**

- Automatically scales pods based on CPU and memory usage
- Maintains performance during traffic spikes
- Reduces costs during low traffic periods

**Current Configuration:**

- **Broker Service**: 2-10 replicas (CPU: 70%, Memory: 80%)
- **Authentication Service**: 2-8 replicas (CPU: 70%, Memory: 80%)
- **Logger Service**: 2-6 replicas (CPU: 75%, Memory: 85%)

### 2. Load Balancing

**NGINX Ingress Controller:**

- Distributes traffic across multiple pods
- Provides SSL termination
- Supports session affinity
- Handles health checks

**Load Balancing Algorithms:**

- **Round Robin**: Default distribution
- **Session Affinity**: Based on request URI
- **Least Connections**: Available via annotations

## Automation Features

### 1. Automated Scaling

The system automatically scales based on:

**Resource Metrics:**

- CPU utilization > 70%
- Memory utilization > 80%

**Custom Metrics:**

- Requests per second > 100
- Response time thresholds
- Error rate monitoring

**Scaling Behavior:**

- **Scale Up**: Aggressive (100% increase every 15s)
- **Scale Down**: Conservative (10% decrease every 60s)
- **Stabilization**: Prevents rapid scaling oscillations

### 2. Health Monitoring

**Automatic Health Checks:**

- Pod readiness probes
- Liveness probes
- Service endpoint monitoring

**High Availability:**

- Pod Disruption Budgets (PDB)
- Minimum available replicas
- Automatic failover

## Usage Guide

### 1. Deploy Everything

```bash
# Deploy all services with scaling enabled
./project/k8s/automation-scripts.sh deploy_all
```

### 2. Manual Scaling

```bash
# Scale broker service to 5 replicas
./project/k8s/automation-scripts.sh scale broker-service 5

# Scale authentication service to 3 replicas
./project/k8s/automation-scripts.sh scale authentication-service 3
```

### 3. Monitor System

```bash
# Check overall health
./project/k8s/automation-scripts.sh health

# Monitor resource usage
./project/k8s/automation-scripts.sh monitor

# Get service logs
./project/k8s/automation-scripts.sh logs broker-service 100
```

### 4. Load Testing

```bash
# Test broker service for 2 minutes with 20 concurrent users
./project/k8s/automation-scripts.sh loadtest http://broker.local 120 20

# Test authentication service
./project/k8s/automation-scripts.sh loadtest http://auth.local 60 10
```

### 5. Autoscaling Control

```bash
# Enable autoscaling for a service
./project/k8s/automation-scripts.sh autoscale broker-service enable

# Disable autoscaling for a service
./project/k8s/automation-scripts.sh autoscale broker-service disable
```

## Configuration Files

### 1. Horizontal Pod Autoscaler (`hpa.yml`)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: broker-service-hpa
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### 2. Ingress Load Balancer (`ingress.yml`)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/load-balance: "round_robin"
    nginx.ingress.kubernetes.io/upstream-hash-by: "$request_uri"
```

### 3. Monitoring (`monitoring.yml`)

- Prometheus ServiceMonitor for metrics collection
- Custom metrics API for advanced scaling
- Pod Disruption Budgets for high availability

## Best Practices

### 1. Resource Management

**Set Appropriate Limits:**

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

**Monitor Resource Usage:**

- Use `kubectl top pods` regularly
- Set up alerts for high resource usage
- Adjust limits based on actual usage patterns

### 2. Scaling Decisions

**When to Scale Up:**

- CPU usage > 70% for 5+ minutes
- Memory usage > 80% for 5+ minutes
- Response time > 500ms
- Error rate > 5%

**When to Scale Down:**

- CPU usage < 30% for 10+ minutes
- Memory usage < 40% for 10+ minutes
- Low traffic periods (night/weekends)

### 3. Database Scaling

**Current Setup:**

- Single PostgreSQL instance (not scalable)
- Single MongoDB instance (not scalable)

**Future Improvements:**

- PostgreSQL: Use StatefulSets with read replicas
- MongoDB: Use MongoDB Operator for sharding
- Consider managed database services

## Troubleshooting

### 1. Scaling Issues

**HPA not working:**

```bash
# Check HPA status
kubectl get hpa
kubectl describe hpa broker-service-hpa

# Check metrics server
kubectl get pods -n kube-system | grep metrics-server
```

**Pods not scaling:**

```bash
# Check resource usage
kubectl top pods
kubectl describe nodes

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### 2. Load Balancing Issues

**Traffic not distributed:**

```bash
# Check ingress status
kubectl get ingress
kubectl describe ingress microservices-ingress

# Check service endpoints
kubectl get endpoints
```

### 3. Performance Issues

**High latency:**

```bash
# Check pod resources
kubectl top pods

# Check network policies
kubectl get networkpolicies

# Monitor logs
kubectl logs -l app=broker-service --tail=100
```

## Monitoring and Alerting

### 1. Key Metrics to Monitor

- **CPU Usage**: Should stay below 70%
- **Memory Usage**: Should stay below 80%
- **Response Time**: Should be under 500ms
- **Error Rate**: Should be under 5%
- **Request Rate**: Monitor for traffic patterns

### 2. Recommended Alerts

```yaml
# Example Prometheus alert rules
- alert: HighCPUUsage
  expr: container_cpu_usage_seconds_total > 0.7
  for: 5m

- alert: HighMemoryUsage
  expr: container_memory_usage_bytes > 0.8
  for: 5m

- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 2m
```

## Cost Optimization

### 1. Resource Optimization

- Use appropriate resource requests/limits
- Monitor actual usage vs. allocated resources
- Implement pod disruption budgets
- Use node affinity for better resource utilization

### 2. Scaling Optimization

- Set appropriate min/max replicas
- Use predictive scaling for known traffic patterns
- Implement graceful shutdown procedures
- Monitor scaling efficiency

## Future Enhancements

### 1. Advanced Scaling

- **Vertical Pod Autoscaler (VPA)**: For memory optimization
- **Cluster Autoscaler**: For node-level scaling
- **Custom Metrics**: Business-specific scaling triggers

### 2. Advanced Load Balancing

- **Service Mesh**: Istio for advanced traffic management
- **Circuit Breakers**: For fault tolerance
- **Rate Limiting**: For API protection

### 3. Database Scaling

- **Read Replicas**: For PostgreSQL
- **Sharding**: For MongoDB
- **Connection Pooling**: For better performance

## Quick Reference

### Common Commands

```bash
# Deploy everything
./project/k8s/automation-scripts.sh deploy_all

# Check health
./project/k8s/automation-scripts.sh health

# Scale service
./project/k8s/automation-scripts.sh scale broker-service 5

# Load test
./project/k8s/automation-scripts.sh loadtest http://broker.local 60 10

# Get logs
./project/k8s/automation-scripts.sh logs broker-service 50
```

### Useful kubectl Commands

```bash
# Check HPA status
kubectl get hpa

# Check resource usage
kubectl top pods

# Check ingress
kubectl get ingress

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Describe service
kubectl describe service broker-service
```

This setup provides a robust, scalable, and automated microservices architecture that can handle varying loads efficiently while maintaining high availability and performance.
