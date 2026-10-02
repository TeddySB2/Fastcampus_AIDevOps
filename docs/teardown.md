# 자원 정리 순서

순서를 지키지 않으면 LB·ENI 가 남아 VPC 삭제가 실패하거나 비용이 계속 나간다.

1. Argo CD 앱 삭제 (root 를 지우면 finalizer 로 하위 앱과 리소스가 함께 정리됨)
   ```bash
   kubectl -n argocd delete application root
   kubectl get ns | grep otel-demo   # 네임스페이스가 사라질 때까지 확인
   ```
2. platform 삭제: `terraform -chdir=infra/platform destroy -var-file=platform.tfvars`
3. cluster 삭제: `terraform -chdir=infra/cluster destroy -var-file=dev.tfvars`
4. 잔여 자원 확인 (리전: ap-northeast-2)
   ```bash
   aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
   aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[].VolumeId'
   aws ec2 describe-network-interfaces --filters Name=status,Values=available --query 'NetworkInterfaces[].NetworkInterfaceId'
   aws ec2 describe-nat-gateways --filter Name=state,Values=available --query 'NatGateways[].NatGatewayId'
   ```
5. 모두 비어 있으면 종료. 남아 있으면 태그(Project=ai-devops-lab)로 출처를 확인한 뒤 수동 삭제.
