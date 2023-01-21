# WordPress appplication template

[![.github/workflows/azure-dev.yml](https://github.com/kopantos/app-template-wordpress/actions/workflows/azure-dev.yml/badge.svg)](https://github.com/kopantos/app-template-wordpress/actions/workflows/azure-dev.yml)

App Templates are packaged app samples designed to reduce the time it takes a developer to deploy their code to Azure. Unlike standalone example code, the goal of App Templates is to provide all the components to deploy an app to Azure with automation via GitHub Actions or other CI/CD services. 

This specific sample consists of example code, CI/CD components, and documentation containing all the required steps to deploy **a fully functional worspress site** and is designed to be compatible with the [Azure Developer CLI(azd)](https://github.com/Azure/azure-dev/) which is currently in preview.

The purpose of App Templates is to deliver and prove the value of accelerated onboarding for developers who are new to Azure.
## Overview 

WordPress (WP or WordPress.org) is a free and open-source content management system (CMS) written in PHP and paired with a MySQL or MariaDB database. Features include a plugin architecture and a template system, referred to within WordPress as "Themes". WordPress was originally created as a blog-publishing system but has evolved to support other web content types including more traditional mailing lists and Internet fora, media galleries, membership sites, learning management systems (LMS) and online stores. One of the most popular content management system solutions in use, WordPress is used by 42.8% of the top 10 million websites as of October 2021.

To function, WordPress at minimum has to be installed on a web server and connect to a mySQL database. So, to deploy Wordpress in Azure a number of different Azure services can be used: [AKS](../mysql/flexible-server/tutorial-deploy-wordpress-on-aks.md), [Virtual Machines](../virtual-machines/linux/tutorial-lamp-stack.md#install-wordpress), and App Service. For a full list of WordPress options on Azure, see [WordPress on Azure Marketplace](https://azuremarketplace.microsoft.com/marketplace/apps?search=wordpress&page=1).

In this application template, you'll learn how to and will be able to easily, quickly create and deploy your first scalable and secure [WordPress](https://www.wordpress.org/) site to Azure, leveraging [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/overview) with [Azure Database for MariaDb](https://learn.microsoft.com/en-us/azure/mariadb/overview). This app template uses a number of Azure resources, and incurs a cost for your Azure Subscription. For pricing, visit [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/). 

## Architecture
![Architecture](assets/azure.png)

## Tech stack:

- Azure
- Azure-database-for-mariadb
- Container Apps / Managed Environments
- Azure Storage
- Azure Key Vault
- Azure Application Gateway
- Azure Networking
- Github Actions
- App Insights
- Log Analytics
- Bicep

## Prerequisites
- Local shell with Azure CLI installed or [Azure Cloud Shell](https://ms.portal.azure.com/#cloudshell/)
- [Azure Developer CLI (azd)](https://github.com/Azure/azure-dev/)
- Azure Subscription, on which you are able to create resources and assign permissions
  - View your subscription using ```az account show``` 
  - If you don't have an account, you can [create one for free](https://azure.microsoft.com/free).  
## Deployment
You can deploy this app template either using the Azure Developer CLI (azd) or the github pipeline provided.

### Using Azure Developer CLI (azd)

1. Clone this repository localy
1. Login to azure from your terminal. You can do this by running the following command:

    ```
    azd login
    ```
1. Verify that you are logged in by running the following command:

    ```
    az account show
    ```
    take a note of the subscription id as you will need it later.
1. Create a folder named ```.azure``` in the root of the project
1. Create a folder in the ```.azure``` folder for the environment you want to deploy to. For example, ```dev``` or ```prod```
1. Create a text file named ```.env``` in the environment folder you created in the previous step and inculde the following environment variables required for the deployment.

    ```
    AZD_PIPELINE_PROVIDER="github"
    AZURE_ADMIN_PASSWORD="<THE JUMPHOST PASSWORD>"
    AZURE_ADMIN_USERNAME="<THE JUMPHOST USERNAME>"
    AZURE_APPLICATION_NAME="<AN APPLICATION NAME>"
    AZURE_ENV_NAME="prod"
    AZURE_FQDN="<THE FQDN OF THE SITE>"
    AZURE_LOCATION="<AN AZURE DC REGION>"
    AZURE_MARIADB_PASSWORD="<THE MARIADB PASSWORD>"
    AZURE_PRINCIPAL_ID=""
    AZURE_SUBSCRIPTION_ID="<YOUR AZURE SUBSCRIPTION ID>"
    resourceGroupName="<THE RESOURCE GROUP NAME>"
    ```

    > **Note:** The ```AZURE_PRINCIPAL_ID``` is the service principal id that will be used for the deployment. Since in this deployment method your user account is used you can leave this blank.

1. Run ```azd provision``` to deploy the app template

### Using Github Actions
1. Fork the repository

    Fork the repository by clicking the 'Fork' button on the top right of the page.
    This creates a copy of the repository in your Github account for you to work in. 


2. Create an Azure Service Principal
    
    The newly created GitHub repo uses GitHub Actions to deploy Azure resources and application code automatically. Your subscription is accessed using an Azure Service Principal. This is an identity created for use by applications, hosted services, and automated tools to access Azure resources. The following steps show how to [set up GitHub Actions to deploy Azure applications](https://github.com/Azure/actions-workflow-samples/blob/master/assets/create-secrets-for-GitHub-workflows.md)

    Create an [Azure Service Principal](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli) with **contributor** permissions on the subscription. The subscription-level permission is needed because the deployment includes creation of the resource group itself.
    
    * login interactively to azure using the following command:
        ```bash
        az login --scope https://graph.microsoft.com//.default
        ```

    * Run the following [az cli](https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) command, either locally on your command line or on the Cloud Shell. 
    Replace {app-name} {subscription-id} with the id of the subscription in GUID format.
        ```bash  
        az ad sp create-for-rbac --name {app-name} --role owner --scopes /subscriptions/{subscription-id} --sdk-auth     
        ```
    * The command should output a JSON object similar to this:
        ```json
        {
            "clientId": "<GUID>",
            "clientSecret": "<GUID>",
            "subscriptionId": "<GUID>",
            "tenantId": "<GUID>",
            "activeDirectoryEndpointUrl": "<URL>",
            "resourceManagerEndpointUrl": "<URL>",
            "activeDirectoryGraphResourceId": "<URL>",
            "sqlManagementEndpointUrl": "<URL>",
            "galleryEndpointUrl": "<URL>",
            "managementEndpointUrl": "<URL>"
        }
        ```

    store this information as it will be used in the next step.

3. Store the following values as GitHub Actions secrets
    + Under your repository name, click Settings. 
    + In the "Security" section of the sidebar, select Secrets. 
    + At the top of the page, click New repository secret
    + Provide the secret name as AZURE_CLIENT_ID
    + Add the clientId field of the service principal that was created in the previous step as the value.
    + Repeat the above steps for the following secrets:
        + AZURE_CLIENT_SECRET
        + AZURE_TENANT_ID
   
4. Repeat the above steps for the following secrets:
    + AZURE_ADMIN_PASSWORD _The password for the jumphost_
    + AZURE_ADMIN_USERNAME _The username for the jumphost_
    + AZURE_APPLICATION_NAME _The name of the application_
    + AZURE_ENV_NAME _The name of the environment e.g. prod_
    + AZURE_FQDN _The FQDN of the WordPress site e.g. http://mywordpress.com_
    + AZURE_LOCATION _The Azure DC region e.g. westeurope_
    + AZURE_MARIADB_PASSWORD _The password for the MariaDB database_
    + AZURE_SUBSCRIPTION_ID _The subscription id_
    + AZURE_PRINCIPAL_ID _The service principal id_
    
    You will need to provide the following values as repository secrets to be used by the GitHub Actions workflow.
    ![Secrets](assets/github-secrets.png)

> **Note:** The ```AZURE_PRINCIPAL_ID``` is the clientId field of the service principal that was created in the previous step.

5. Execute the azure-dev.yml action workflow

    + Under your repository name, click Actions .
    + In the left sidebar, click the workflow "azure-dev.yml".
    + Above the list of workflow runs, select Run workflow .
    + Use the Branch dropdown to select the workflow's main branch, Click Run workflow .

After deployment, below resources will be created

![Resources](assets/azure-resources.png)


## Getting Started with Wordpress
Since this is a brand new Wordpress site, you will need to complete the initial setup which creates the Database schema and populates it with seed data as well as creates the ```wp-config.php``` file to read the configuration from the environment variables.

To do this, you will first need to **map the FQDN of the site you specified when provisioning the template to the public IP address of the Azure Application Gateway**. You can do this by either adding an entry to your pubcic dns zone or simply by adding an entry to your hosts file.

Once you have mapped the FQDN to the public IP address, you can navigate to the site in your browser and complete the initial setup.
### New WordPress instance
1. Navigate to the http://FQDN using your browser

1. Select the wordpress language and click Continue
    ![Setup](assets/wp-install.png)

1. Fill in the site title, the administrator username, password, and email address and click Install WordPress

    ![Setup](assets/wp-install-step-1.png)

1. Now you can navigate to the site in your browser and login using the username and password you specified during the setup to access the administration console or navigate to the site to see it.

### [Migrate an existing WordPress instance](migrate-wordpress.md)

### [Enanble Redis Cache](redis-cache.md)

### [The Wordpress Docker Image](customize-docker-image.md)

## Clean up resources
When you are done, you can delete all the Azure resources created with this template by running the following command:

```bash
resourceGroup=<RESOURCE GROUP NAME>
az group delete --name $resourceGroup
```

or if you deployed using the azd cli

```
azd down
```

## [Changelog](CHANGELOG.md)

## [Contributing](CONTRIBUTING.md)

## [License](LICENSE.md)
## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
