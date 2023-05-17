# Week 10 — CloudFormation Part 1
- CloudFormation validation template example:
aws cloudformation validate-template --template-body file:///workspace/aws-bootcamp-cruddur-2023/aws/cfn/template.yaml
- another way to debug is to use CLoudFormation lint. We need to run the following command to install it:
`pip install cfn-lint`
- we need to install cargo, for CFN guard. This will allow us to write Policy as Code:
`cargo install cfn-guard`
