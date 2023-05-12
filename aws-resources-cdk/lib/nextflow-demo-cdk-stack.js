const cdk = require('@aws-cdk/core');
const S3 = require('@aws-cdk/aws-s3')
const batch = require('@aws-cdk/aws-batch')
const ec2 = require('@aws-cdk/aws-ec2')
const iam = require('@aws-cdk/aws-iam')
const ecs = require('@aws-cdk/aws-ecs')
const cloud9 = require('@aws-cdk/aws-cloud9')
const {EbsDeviceVolumeType} = require("@aws-cdk/aws-ec2/lib/volume");

const createS3Resources = (stack) => {
    const tempBucket = new S3.Bucket(stack, `nextflow-temp`, {
        autoDeleteObjects: true,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
    })

    const outputBucket = new S3.Bucket(stack, `nextflow-output`, {
        autoDeleteObjects: true,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
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

const createIamEC2InstanceProfile = (stack) => {
    const administratorAccessPolicy = iam.ManagedPolicy.fromAwsManagedPolicyName("AdministratorAccess")
    const iamEc2Role = new iam.Role(stack, "aws-ec2-nextflow-demo-role-id", {
        roleName: "aws-ec2-nextflow-demo-role",
        assumedBy: new iam.CompositePrincipal(new iam.ServicePrincipal("ec2.amazonaws.com"))
            .addPrincipals(new iam.ServicePrincipal("batch.amazonaws.com"))
        ,
        managedPolicies: [administratorAccessPolicy]
    })

    return new iam.CfnInstanceProfile(stack, "aws-ec2-nextflow-demo-instance-profile-id", {
        roles: [iamEc2Role.roleName]
    })
}

const createIamBatchRole = (stack) => {
    const administratorAccessPolicy = iam.ManagedPolicy.fromAwsManagedPolicyName("AdministratorAccess")
    return new iam.Role(stack, "aws-batch-nextflow-demo-role-id", {
        // roleName: "aws-batch-nextflow-demo-role",
        assumedBy: new iam.ServicePrincipal('batch.amazonaws.com'),
        managedPolicies: [administratorAccessPolicy]
    })
}

const createBatchResources = (stack) => {

    const iamBatchRole = createIamBatchRole(stack)
    const instanceProfile = createIamEC2InstanceProfile(stack)
    const vpc = ec2.Vpc.fromLookup(stack, "VPC", {
            isDefault: true
        }
    )

    const largerStorageTemplate = new ec2.LaunchTemplate(stack, 'LaunchTemplate', {
        launchTemplateName: 'extra-storage-template',
        machineImage: ecs.EcsOptimizedImage.amazonLinux2(ecs.AmiHardwareType.GPU),
        instanceType: ec2.InstanceType.of(ec2.InstanceClass.R5, ec2.InstanceSize.LARGE),
        spotOptions: {
            maxPrice: 10000,
            interruptionBehavior: ec2.SpotInstanceInterruption.STOP,
            requestType: ec2.SpotRequestType.ONE_TIME,
        },
        blockDevices: [
            {
                deviceName: '/dev/sda1',
                volume: ec2.BlockDeviceVolume.ebs(200, {
                    volumeType: ec2.EbsDeviceVolumeType.GP3
                }),
            },
        ],
    });

    // const extraStorageLaunchTemplate = new ec2.CfnLaunchTemplate(stack, 'LaunchTemplate', {
    //     launchTemplateName: 'extra-storage-template',
    //     launchTemplateData: {
    //         instanceType: 'm5.small',
    //         iamInstanceProfile: {
    //           arn: instanceProfile.attrArn,
    //           name: instanceProfile.instanceProfileName
    //         },
    //         instanceMarketOptions: {
    //             spotOptions: {
    //                 instanceInterruptionBehavior: 'instanceInterruptionBehavior',
    //                 maxPrice: 'maxPrice',
    //                 spotInstanceType: 'spotInstanceType',
    //                 validUntil: 'validUntil',
    //             },
    //         },
    //         blockDeviceMappings: [
    //             {
    //                 deviceName: '/dev/xvdcz',
    //                 ebs: {
    //                     encrypted: true,
    //                     volumeSize: 100,
    //                     volumeType: 'gp3',
    //                 },
    //             },
    //         ],
    //     },
    // });

    const awsSpotManagedComputeEnv = new batch.ComputeEnvironment(stack, `aws-managed-compute-env-spot`, {
        computeResources: {
            // type: batch.ComputeResourceType.SPOT,
            // allocationStrategy: batch.AllocationStrategy.SPOT_CAPACITY_OPTIMIZED,
            launchTemplate: {
                launchTemplateName: "extra-storage-template",
                version: "$Latest",
            },
            // launchTemplate: new ec2.LaunchTemplate(stack, 'LaunchTemplate', {
            //     machineImage: ecs.EcsOptimizedImage.amazonLinux2(ecs.AmiHardwareType.STANDARD),
            //     instanceType: ec2.InstanceType.of(ec2.InstanceClass.R5, ec2.InstanceSize.LARGE)
            // }),
            vpc: vpc
        },
        // computeEnvironmentName: "spot-compute-env",
        serviceRole: iamBatchRole
    });

    awsSpotManagedComputeEnv.node.addDependency(largerStorageTemplate)

    const awsOnDemandManagedComputeEnv = new batch.ComputeEnvironment(stack, `aws-managed-compute-env-on-demand`, {
        computeResources: {
            type: batch.ComputeResourceType.ON_DEMAND,
            allocationStrategy: batch.AllocationStrategy.BEST_FIT,
            vpc: vpc,
            instanceRole: instanceProfile.attrArn,
            desiredvCpus: 8,
            maxvCpus: 2048
        },
        // computeEnvironmentName: "on-demand-compute-env",
        serviceRole: iamBatchRole
    });

    const jobQueue = new batch.JobQueue(stack, `job-queue`, {
        computeEnvironments: [
            {
                computeEnvironment: awsSpotManagedComputeEnv,
                order: 1,
            },
            {
                computeEnvironment: awsOnDemandManagedComputeEnv,
                order: 10,
            },
        ],
        jobQueueName: "nextflow-job-queue-demo"
    });

    new cdk.CfnOutput(stack, 'iamBatchRoleName', {
        value: iamBatchRole.roleName,
        description: 'The name of the iam',
        exportName: 'iamBatchRole',
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
