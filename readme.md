
# Purview Exchange DLP Approval Workflow

This project provides a solution to automate the incident response for Microsoft Purview DLP (Data Loss Prevention) policies in Exchange Online.

When a DLP policy quarantines an email, this solution triggers a Power Automate approval flow. If approved, a custom Azure Function is called to release the item from quarantine. This guide details the complete setup process.

## Setup Instructions

Follow these steps to deploy and configure all the necessary components.

### Part 1: Azure Function & Managed Identity

First, we'll deploy the Azure Function and configure its identity, which is responsible for releasing items from quarantine.

1.  **Get Initial Domain:**
    * Navigate to the **Azure Portal / Entra ID**.
    * Go to **Custom Domain Names**.
    * Filter the list by **Status = Initial (Available)**.
    * Copy this initial domain name (e.g., `M365...onmicrosoft.com`). You will need this for the Function deployment.
  
      <img width="1314" height="425" alt="image" src="https://github.com/user-attachments/assets/41575b06-398a-4b18-9038-f981892e44c6" />


2.  **Deploy the Azure Function:**
    * Use the "Deploy to Azure" button:
    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](
  https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fbrunofreitas-br%2FPurviewDLP-ApprovalsWithFlow%2Fmain%2Fazuredeploy.json
)
    * Select your **Subscription**, **Resource group**, and **Region**.
    * Provide a unique **Function App Name**.
    * In the **EXO_ORG** field, paste the initial domain you copied in the previous step.
    * Click **Review + Create** and then **Create** to deploy.

      <img width="575" height="556" alt="image" src="https://github.com/user-attachments/assets/e5b3df57-c324-44b8-80f8-9e48e0f8f904" />


3.  **Enable Managed Identity:**
    * Once the Function App is deployed, navigate to its resource page.
    * Go to **Settings > Identity**.
    * Select the **System assigned** tab, switch the Status to **On**, and click **Save**.
    * Copy the **Object (principal) ID** for the Managed Identity.

    <img width="587" height="490" alt="image" src="https://github.com/user-attachments/assets/659bc5d5-1361-461a-bfbd-4c3c8d4d7be1" />


4.  **Get Application ID:**
    * Go back to **Entra ID > Enterprise applications**.
    * **Important:** Remove the default "Application type" filter to search *all* applications.
    * Search for the **Object ID** you just copied.
    <img width="426" height="390" alt="image" src="https://github.com/user-attachments/assets/5e51cbd7-4297-4785-8735-70d0f0fb43b4" />

    * Click on the Enterprise Application that appears in the results (it should match your Function App's name).
    * From the **Overview** page, copy the **Application ID**.
    <img width="443" height="250" alt="image" src="https://github.com/user-attachments/assets/ee7233e4-14e9-4e62-ba85-620f049a3f3f" />

5.  **Assign Permissions:**
    * Run the `MI-EXO_RoleAssignment.ps1` script provided in this repository.
    * Before running, replace the placeholders in the script with the **Object ID** and **Application ID** you collected.
    * *Tip: Running the script part-by-part can make troubleshooting easier*.

### Part 2: Service Account Setup

This flow requires a dedicated service account to interact with various M365 services.

1.  **Create Service Account:**
    * In the **Entra ID Portal** or **M365 Admin Center**, create a new user account (e.g., `PurviewDLP-SVC`).
    * Set a strong password.
  
    <img width="508" height="414" alt="image" src="https://github.com/user-attachments/assets/42fdc6a7-0434-4b67-a58c-5680aabf09b2" />


2.  **Assign License:**
    * On the **Product licenses** step, you must assign at least one license that includes **Exchange Online**.
    * This is a prerequisite for the account to read emails that will be forwarded to the shared mailbox.
  
    <img width="425" height="351" alt="image" src="https://github.com/user-attachments/assets/2aa62821-e377-44eb-9d7a-fbf8374f92fd" />


3.  **Finalize Account:**
    * Do **not** add any administrative roles at this point. We will assign a specific, limited role in the next step.
    * Complete the user creation process.
  
    <img width="572" height="478" alt="image" src="https://github.com/user-attachments/assets/def4fb4c-d492-42f3-9f50-652fb91859a5" />


4.  **Assign Required Role:**
    * In the **Entra ID Portal**, find the service account you just created.
    * Navigate to **Assigned roles** and click **Add assignments**.
    <img width="944" height="487" alt="image" src="https://github.com/user-attachments/assets/e787c960-bd7c-4f4d-b366-845b32f6db6a" />

    * Select the **Directory Readers** role. This is required for the *Office 365 Users* connector in Power Automate.
    * If your organization uses PIM, ensure this role is set as **Active** (not *Eligible*).
  
    <img width="499" height="731" alt="image" src="https://github.com/user-attachments/assets/28009869-8b53-4b46-bd67-004748023736" />




### Part 3: Shared Mailbox Setup

A shared mailbox is needed to receive DLP incident reports.

1.  **Create Shared Mailbox:**
    * Go to the **Exchange admin center** > **Mailboxes**.
    * Click **Add a shared mailbox**.
    * Fill in the required fields (e.g., Display name: `EXO DLP Alert Reports`) and click **Create**.
  
    <img width="1407" height="366" alt="image" src="https://github.com/user-attachments/assets/70a0d461-7592-4eb9-be20-a2291a9ad032" />



2.  **Add Members:**
    * After the mailbox is created, click **Add users to this mailbox**.
    * Add the service account you created in Part 2 (or your own admin account) as a member.
  
    <img width="425" height="337" alt="image" src="https://github.com/user-attachments/assets/e108453f-40dc-4f47-9f0f-d5c5ef49c317" />


### Part 4: Power Automate Flow Import & Configuration

Now, we'll import and configure the main Power Automate workflow.

1.  **Import the Flow:**
    * In the **Power Automate Portal**, go to **My flows**.
    * Click **Import** and select **Import Package (Legacy)**.
    <img width="1022" height="326" alt="image" src="https://github.com/user-attachments/assets/9ff97993-7d40-4e97-95dd-05e7616a4328" />

    * Click **Upload** and select the `Flow-PurviewEXODLP-SendApprovaltoManager.zip` file.

    <img width="1163" height="426" alt="image" src="https://github.com/user-attachments/assets/bcf344a5-076c-4113-99b2-13f108530cb1" />




2.  **Configure Connections:**
    * The package will require several connections. For each resource listed under "Related resources," click the **edit icon** or **"Select during import"**.
  
    <img width="1872" height="672" alt="image" src="https://github.com/user-attachments/assets/a1d1cdfe-6d9f-4cd6-9f0a-3eeca419758c" />


    * In the side panel, click **Create new**.

    <img width="1871" height="666" alt="image" src="https://github.com/user-attachments/assets/0d4d0b90-eed8-4e13-a3da-30d1dc95a68b" />


    * You will be prompted to create a **New connection**.

    <img width="1851" height="514" alt="image" src="https://github.com/user-attachments/assets/0a116f3d-48a7-4d44-b243-56fd1eabd6ad" />


    * Search for and create connections for all of the following:
        * Office 365 Users
        * Office 365 Outlook
        * Standard Approvals
        * Microsoft 365 compliance
    <img width="1594" height="699" alt="image" src="https://github.com/user-attachments/assets/5442e009-cc79-4584-87da-74d60a9f3bb7" />


    
    * For each, click the **+** icon, then **Create**, and sign in with credentials (use the new service account where appropriate).
    <img width="425" height="231" alt="image" src="https://github.com/user-attachments/assets/2ff1fd5c-1f89-4c96-bc18-aac70a4f5ec5" />


    * **Note:** The **Microsoft 365 compliance** connection *must* use an account with permissions to create the DLP policy.
    * After creating each connection, return to the "Import setup" panel, select the connection you just made, and click **Save**.
    <img width="1743" height="619" alt="image" src="https://github.com/user-attachments/assets/35428752-1e3e-4c5a-af3f-0c6edee74aca" />


   
    * Once all connections are configured (no red icons), click the main **Import** button.
    <img width="1015" height="696" alt="image" src="https://github.com/user-attachments/assets/28eee658-9711-4dc3-beaf-e00d8a2de7b2" />



2.  **Activate and Edit the Flow:**
    * When the import is successful, click **Open flow**.
    <img width="425" height="87" alt="image" src="https://github.com/user-attachments/assets/d3a342c5-5df9-44bc-86c2-6c90058ffc18" />

    * The flow is imported in a "Disabled" state. In the toolbar, click **Turn on** to enable it.
    <img width="1376" height="620" alt="image" src="https://github.com/user-attachments/assets/9f9df33a-aca8-437f-9ec5-40b465fd0e96" />


    * Click **Edit** to configure the flow's variables.
    * Find the **'Compose - ReleaseQuarantine Function URL'** step and update the **Inputs** field with your Azure Function's URL (which you can get from the Function App's *Overview* page in the Azure Portal).
    <img width="1834" height="724" alt="image" src="https://github.com/user-attachments/assets/eb21f871-5c5a-4773-9d13-f982277ff2e4" />


    * Find the **'Compose - Shared Mailbox address'** step and update the **Inputs** field with the email address of the shared mailbox you created in Part 3.
    <img width="1115" height="760" alt="image" src="https://github.com/user-attachments/assets/206beaae-629b-43b4-b71b-7d7f93ec54fd" />


    * **Save** the flow.

### Part 5: Purview DLP Policy Configuration

Finally, create the DLP policy that ties everything together.

1.  **Create DLP Policy:**
    * In the **Microsoft Purview portal**, create a new DLP policy & rule.
    * In the **Locations** settings, select only **Exchange**.

2.  **Configure Rule Actions:**
    * In the **Actions** section of the rule, configure two actions:
    * **Action 1:** **Deliver the message to the hosted quarantine**.
    * **Action 2 (AND):** **Start a Power Automate workflow**. Select the **'EXO DLP - Approval to Manager'** flow you imported.
    <img width="1131" height="694" alt="image" src="https://github.com/user-attachments/assets/c9f588a5-e841-4d1a-aa68-6940b21f463d" />


3.  **Configure Incident Reports:**
    * In the **Incident reports** section, turn on **Use email incident reports to notify you when a policy match occurs**.
    * In the **Send email alerts to these people** field, add the email address of the shared mailbox you created in Part 3.
    <img width="665" height="750" alt="image" src="https://github.com/user-attachments/assets/a7e958d2-cbdd-4394-9d1a-9854f4dbba88" />

    * Save and activate your DLP policy.
