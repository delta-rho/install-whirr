
# Whirr Configuration #

1. This is the README for 0.8.2 version of Whirr.
2. This version of Whirr works with CDH - Cloudera Hadoop Distribution 0.4x

## Install Whirr ##
1. There are multiple ways to install Whirr
2. You can use OS specific repositories or manually compile it.
3. Follow this link if you plan to simply use OS specific installation
        --> http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH4/4.2.0/CDH4-Installation-Guide/cdh4ig_topic_22_2.html
4. Next create a ".whirr" folder in your home directory and drop the folder "functions" from this repository into the .whirr folder.
AND FOLLOW from the 5th bullet in the next section.

## Manual Installation of Whirr ##
1. If you decide to manually install Whirr then download Whirr from this place
	--> http://archive.apache.org/dist/whirr/whirr-0.8.2/whirr-0.8.2.tar.gz
2. Extract the files "tar -xvzf whirr-0.8.2.tar.gz"
3. copy the folder "functions" from this git repo into whirr.0.8.2 folder (it should be extracted)"
4. Next create a ".whirr" folder in your home directory "~/.whirr" and drop the w8.whirr.rhipe.properties file into that. 
5. Add your AWS credentials as environment variables and uncomment these variables in your w8.whirr.rhipe.properties file, or enter then in your w8.whirr.rhipe.properties file
````
	export WHIRR_PROVIDER=aws-ec2
	export WHIRR_IDENTITY=$AWS_ACCESS_KEY_ID
	export WHIRR_CREDENTIAL=$AWS_SECRET_ACCESS_KEY
````
6. Generate your SSH key
````
	ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa_whirr
````
7. Start and stop the cluster as follows (the executable "whirr" will vary, depending on where you are trying to execute it from)
````
	whirr.0.8.2/bin/whirr launch-cluster --config ~/.whirr/w8.whirr.rhipe.properties
	whirr.0.8.2/bin/whirr destroy-cluster --config ~/.whirr/w8.whirr.rhipe.properties
````
8. After the start up make sure you add port 3838 and 8787 to your security group on AWS
8a. From this you will have to login to your aws dashboard, click on security groups
8b. Go to Security groups, and select jclouds w8 rhipe
8c. Click on actions and "edit inbound rules"
8d. Now add port 3838 and then add 8787 for the specific IP you would like to access it from.

9. MAKE SURE YOU DO NOT PROVIDE ANY OF YOUR PRIVATE EC2 ACCESS DETAILS IN EITHER OF THE CONFIGURATION. AND PLEASE CHANGE THE PASSWORD FOR "user3"
