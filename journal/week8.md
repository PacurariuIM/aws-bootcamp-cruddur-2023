# Week 8 — Serverless Image Processing

The task for this week was to implement the user avatar image, using IaC(infrastructure as code) tools like AWS CDK and CloudFormation.

## Implement CDK stack
- first we'll create a S3 bucket to store the uploaded images, `crazyfrog-uploaded-avatars`;
- next we'll create a bucket, `assets.crazyfroggg-project.com` (your domain name) which will be used to serve the processed images to our application. This bucket will contain 2 folders, `avatars/` and `banners/`;
- 