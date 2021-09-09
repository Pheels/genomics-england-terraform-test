import boto3
import botocore
import os

from PIL import Image

s3 = boto3.resource('s3')

def strip(event, context):
    for item in event['Records']:
        key = item['s3']['object']['key']
        bucket = item['s3']['bucket']['name']
        try:
            s3.Bucket(bucket).download_file(key, '/tmp/in.jpg')
        except botocore.exceptions.ClientError as e:
            print("Failed to download image " + key + " from bucket " + bucket)
            print(e.response)
            raise

        if strip_exif_metadata('/tmp/in.jpg', '/tmp/out.jpg'):
            try:
                s3.meta.client.upload_file('/tmp/out.jpg', os.environ.get('BUCKET_B'), key)
            except botocore.exceptions.ClientError as e:
                print("Failed to upload image " + key + " to bucket " + os.environ.get('BUCKET_B'))
                print(e.response)
        else:
            print("Failed to strip metadata for image " + key + " from bucket " + bucket)


    return {"result": "success"}

def strip_exif_metadata(filein, fileout):
    try:
        image = Image.open(filein)
        data = list(image.getdata())
        image_without_exif = Image.new(image.mode, image.size)
        image_without_exif.putdata(data)
        image_without_exif.save(fileout)
        return True
    except Exception as e:
        print(e)
        return False
