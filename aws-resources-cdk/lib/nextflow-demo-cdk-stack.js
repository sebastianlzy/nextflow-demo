const cdk = require('@aws-cdk/core');
const S3 = require('@aws-cdk/aws-s3')
const batch = require('@aws-cdk/aws-batch')
const ec2 = require('@aws-cdk/aws-ec2')
const iam = require('@aws-cdk/aws-iam')
const cloud9 = require('@aws-cdk/aws-cloud9')

const createS3Resources = (stack) => {
    const tempBucket = new S3.Bucket(stack, `nextflow-temp`, {
        autoDeleteObjects: true,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
    })
    const outputBucket = new S3.Bucket(stack, `nextflow-output`, {
        autoDeleteObjects: true,
        removalPolicy: cdk.RemovalPolicy.DESTROY
    })

    new cdk.CfnOutput(stack, 'tempBucketName', {
        value: tempBucket.bucketName,
        description: 'The name of the temp s3 bucket',
        exportName: 'tempS3BucketName',
    });
    new cdk.CfnOutput(stack, 'outputBucketName', {
        value: outputBucket.bucketName,
        description: 'The name of the output s3 bucket',
        exportName: 'outputS3BucketName',
    });
}

const createBatchResources = (stack) => {
    const administratorAccessPolicy = iam.ManagedPolicy.fromAwsManagedPolicyName("AdministratorAccess")
    const iamRole = new iam.Role(stack, "aws-batch-nextflow-demo-role-id", {
        roleName: "aws-batch-nextflow-demo-role",
        assumedBy: new iam.ServicePrincipal('batch.amazonaws.com'),
        managedPolicies: [administratorAccessPolicy]
    })

    const vpc = ec2.Vpc.fromLookup(stack, "VPC", {
            isDefault: true
        }
    )
    const awsManagedComputeEnv = new batch.ComputeEnvironment(stack, `aws-managed-compute-env-spot`, {
        computeResources: {
            type: batch.ComputeResourceType.SPOT,
            allocationStrategy: batch.AllocationStrategy.SPOT_CAPACITY_OPTIMIZED,
            vpc: vpc,
        },
        serviceRole: iamRole
    });

    const jobQueue = new batch.JobQueue(stack, `job-queue`, {
        computeEnvironments: [
            {
                computeEnvironment: awsManagedComputeEnv,
                order: 1,
            },
        ],
        jobQueueName: "nextflow-job-queue-demo"
    });

    new cdk.CfnOutput(stack, 'iamRoleName', {
        value: iamRole.roleName,
        description: 'The name of the iam',
        exportName: 'iamRoleName',
    });
    new cdk.CfnOutput(stack, 'jobQueueName', {
        value: jobQueue.jobQueueName,
        description: 'The name of the job queue',
        exportName: 'jobQueueName',
    });
}

class NextflowDemoCdkStack extends cdk.Stack {
    /**
     *
     * @param {cdk.Construct} scope
     * @param {string} id
     * @param {cdk.StackProps=} props
     */
    constructor(scope, id, props) {
        super(scope, id, props);

        createS3Resources(this)
        createBatchResources(this)
    }
}

module.exports = {NextflowDemoCdkStack: NextflowDemoCdkStack}
