const cdk = require('@aws-cdk/core');
const S3 = require('@aws-cdk/aws-s3')
const batch = require('@aws-cdk/aws-batch')
const ec2 = require('@aws-cdk/aws-ec2')
const iam = require('@aws-cdk/aws-iam')
const ecs = require('@aws-cdk/aws-ecs')
const cloud9 = require('@aws-cdk/aws-cloud9')
const {EbsDeviceVolumeType} = require("@aws-cdk/aws-ec2/lib/volume");

const launchTemplateName = "extra-storage-launch-template"

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

const createLaunchTemplate = (stack) => {
    /**
     * Create user data
     */
    const bootHookConf = ec2.UserData.forLinux();
    bootHookConf.addCommands('cloud-init-per once docker_options echo \'OPTIONS="${OPTIONS} --storage-opt dm.basesize=40G"\' >> /etc/sysconfig/docker');

    const setupCommands = ec2.UserData.forLinux();
    setupCommands.addCommands('sudo yum install awscli ');

    const multipartUserData = new ec2.MultipartUserData();
// The docker has to be configured at early stage, so content type is overridden to boothook
    multipartUserData.addPart(ec2.MultipartBody.fromUserData(bootHookConf, 'text/cloud-boothook; charset="us-ascii"'));
// Execute the rest of setup
    multipartUserData.addPart(ec2.MultipartBody.fromUserData(setupCommands));

    /**
     * Create Launch Template
     *
     */


    const largerStorageTemplate = new ec2.LaunchTemplate(stack, 'LaunchTemplate', {
        launchTemplateName: launchTemplateName,
        userData: multipartUserData,
        machineImage: ecs.EcsOptimizedImage.amazonLinux2(ecs.AmiHardwareType.STANDARD),
        instanceType: ec2.InstanceType.of(ec2.InstanceClass.R5, ec2.InstanceSize.LARGE),
        blockDevices: [
            {
                deviceName: '/dev/sda1',
                volume: ec2.BlockDeviceVolume.ebs(200, {
                    volumeType: ec2.EbsDeviceVolumeType.GP3
                }),
            },
        ],
    });
}

const createBatchResources = (stack) => {


    const jobQueueName = "nextflow-job-queue-demo"
    const ec2KeyPair = "leesebas-new-rsa"
    const iamBatchRole = createIamBatchRole(stack)
    const instanceProfile = createIamEC2InstanceProfile(stack)
    const vpc = ec2.Vpc.fromLookup(stack, "VPC", {
            isDefault: true
        }
    )

    const securityGroup = new ec2.SecurityGroup(stack, 'aws-security-group', {
        allowAllOutbound: true,
        vpc: vpc,
    })
    securityGroup.addIngressRule(ec2.Peer.anyIpv4(), ec2.Port.allTraffic(), 'Frm anywhere');


    /**
     * Suppose that any of these parameters (except the Amazon EC2 tags) are specified both in the launch template and in the compute environment configuration.
     * Then, the compute environment parameters take precedence. Amazon EC2 tags are merged between the launch template and the compute environment configuration.
     * If there's a collision on the tag's key, the value in the compute environment configuration takes precedence.
     */

    const awsSpotManagedComputeEnv = new batch.ComputeEnvironment(stack, `aws-managed-compute-env-spot`, {
        computeResources: {
            type: batch.ComputeResourceType.SPOT,
            allocationStrategy: batch.AllocationStrategy.SPOT_CAPACITY_OPTIMIZED,
            launchTemplate: {
                launchTemplateName: launchTemplateName,
                version: "$Latest",
            },
            vpc: vpc,
            minvCpus: 0,
            maxvCpus: 100,
            instanceRole: instanceProfile.attrArn,
            ec2KeyPair: ec2KeyPair,
            securityGroups: [securityGroup],
            computeResourcesTags: {"Name": "nextflow-spot-managed-compute-env"}

        },
        serviceRole: iamBatchRole
    });

    // awsSpotManagedComputeEnv.node.addDependency(largerStorageTemplate)

    const awsOnDemandManagedComputeEnv = new batch.ComputeEnvironment(stack, `aws-managed-compute-env-on-demand`, {
        computeResources: {
            type: batch.ComputeResourceType.ON_DEMAND,
            allocationStrategy: batch.AllocationStrategy.BEST_FIT,
            vpc: vpc,
            instanceRole: instanceProfile.attrArn,
            desiredvCpus: 8,
            maxvCpus: 2048,
            computeResourcesTags: {"Name": "nextflow-on-demand-managed-compute-env"}
        },
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
        jobQueueName: jobQueueName
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

        createLaunchTemplate(this)
        createS3Resources(this)
        createBatchResources(this)
    }
}

module.exports = {NextflowDemoCdkStack: NextflowDemoCdkStack}
