# Migrate an existing WordPress instance
To migrate an existing WordPress instance, you will need to perform two tasks. First export the database from the existing site and import it into the new site and then copy the site files to the new site.

To do this navigate to the Azure Portal and open a Bash cloud shell session. Make sure you are loged in to the correct subscription using tha ```az account show``` command

1. Create a firewall rule to connect to the database

    ```bash
    resourceGroup=<RESOURCE GROUP NAME>
    mariaDBServer=<MARIADB SERVER NAME> #<name> with out the domain name
    clientIP=$(curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//')
    az mariadb server firewall-rule create --resource-group $resourceGroup --server $mariaDBServer --name allow-client --start-ip-address $clientIP --end-ip-address $clientIP
    ```

1. Connect to the database using the following command

    ```bash
    username=<DB ADMIN USERNAME>    #db_admin@<name>
    mysql -u $username -p -h $mariaDBServer
    ```
1. Once connected, restore your existing wordpress database

    ```sql
    mysql -u $username -p -h <MARIADB SERVER NAME>-prod.mariadb.database.azure.com wordpress < <PATH TO YOUR BACKUP FILE>
    ```
1. Make sure the siteurl and home configuration entries are pointing to the new site
    ```sql
    use wordpress;
    update wp_options set option_value = 'http://FQDN' where option_name = 'siteurl';
    update wp_options set option_value = 'http://FQDN' where option_name = 'home';
    ```
1. Create a firewall rule to connect to the Azure storage account
    ```bash
    resourceGroup=<RESOURCE GROUP NAME>
    storageAccount=<STORAGE ACCOUNT NAME>
    clientIP=<YOUR IP>
    az storage account firewall-rule create --resource-group $resourceGroup --account-name $storageAccount --name allow-client --start-ip $clientIP --end-ip $clientIP

    azcopy login --tenant-id <TENANT ID>
    azcopy copy 'myDirectory\*' 'https://$storageAccount.file.core.windows.net/fileshare' --recursive
    ```

1. Map the FQDN of your site to the public IP address of the Azure Application Gateway. You can do this by adding an entry to your hosts file so that only you can access the new WordPress instance.

> **Note:** This is a basic migration guide. As WordPress sites often contain various customizations you might need to refer to the [WordPress documentation](https://wordpress.org/support/article/moving-wordpress/) for more information on migrating WordPress sites.
