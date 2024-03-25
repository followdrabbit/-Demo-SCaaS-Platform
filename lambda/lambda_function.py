import json
import boto3

def lambda_handler(event, context):
    # Cliente EC2 para interagir com o serviço Amazon EC2
    ec2_client = boto3.client('ec2')

    # Extrai e decodifica o corpo da solicitação do evento
    request_body = event.get('body', '{}')
    request_data = json.loads(request_body)

    # Validação dos dados da requisição
    required_keys = ["auth_token", "ami"]
    if not all(key in request_data for key in required_keys):
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'JSON is missing required keys'})
        }
    if not all(isinstance(request_data[key], str) for key in required_keys):
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'Values for required keys should be strings'})
        }
    if len(request_data) != len(required_keys):
        return {
            'statusCode': 400,
            'body': json.dumps({'message': 'JSON has additional properties'})
        }

    try:
        # Verifica se a AMI especificada existe
        ami_id = request_data['ami']
        response = ec2_client.describe_images(ImageIds=[ami_id])
        if not ('Images' in response and response['Images']):
            return {
                'statusCode': 404,
                'body': json.dumps({'message': 'AMI not found'})
            }

        # Cria uma instância EC2 t2.micro sem IP público
        instance_response = ec2_client.run_instances(
            ImageId=ami_id,
            InstanceType='t2.micro',
            MaxCount=1,
            MinCount=1,
            NetworkInterfaces=[{
                'AssociatePublicIpAddress': False,
                'DeviceIndex': 0
            }]
        )
        instance_id = instance_response['Instances'][0]['InstanceId']
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'EC2 instance created successfully',
                'instance_id': instance_id
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Failed to create EC2 instance: {str(e)}'})
        }
