## Understanding of Requirements

    ### 1. Application Structure
    - **Two Portals**: Admin Portal and Merchant Portal
    - **User Types**:
      - Admin Portal: Global admin, super users, makers, checkers
      - Merchant Portal: Merchant-specific users and roles
    - **Database Design**:
      - Admin Portal: `Admin_EE_$` tables (already implemented)
      - Merchant Portal: `Merchant_EE_$` tables (to be designed)

    ### 2. Role Hierarchy & Flow
    - **Admin Portal** → Creates merchant super admins
    - **Merchant Portal Super Admin** → Creates merchant-specific roles
    - **Maker-Checker Pattern**: All activities require approval workflow
    - **Role Scopes**: `Maker_TaskA`, `Checker_TaskA`, `Maker+Checker_TaskA`

    ### 3. Cross-Portal Role Creation Process
    1. `maker_merchant_portal_role_creator` (Admin Portal) submits request
    2. `checker_merchant_portal_role_creator` (Admin Portal) approves
    3. Results in creation of `superadmin_merchant_portal_for_merchant_X` role
    4. Super admin creates additional merchant-specific roles

    ### 4. Merchant Onboarding Scenario
    - **Merchants**: X and Y
    - **Tasks**: reward_program_creation, reward_disbursement
    - **Required Roles**: maker/checker combinations for each task per merchant

    ## Database Schema Design

    ### Core Merchant Tables Structure

    ```sql
    -- Base merchant information
    CREATE TABLE MERCHANT_EE_MERCHANTS (
        MERCHANT_ID VARCHAR2(50) PRIMARY KEY,
        MERCHANT_NAME VARCHAR2(200) NOT NULL,
        STATUS VARCHAR2(20) DEFAULT 'ACTIVE',
        CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CREATED_BY VARCHAR2(100),
        MODIFIED_DATE TIMESTAMP,
        MODIFIED_BY VARCHAR2(100)
    );

    -- Merchant users
    CREATE TABLE MERCHANT_EE_USERS (
        USER_ID VARCHAR2(50) PRIMARY KEY,
        MERCHANT_ID VARCHAR2(50) NOT NULL,
        USERNAME VARCHAR2(100) UNIQUE NOT NULL,
        EMAIL VARCHAR2(255),
        FIRST_NAME VARCHAR2(100),
        LAST_NAME VARCHAR2(100),
        STATUS VARCHAR2(20) DEFAULT 'ACTIVE',
        CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        LAST_LOGIN TIMESTAMP,
        CONSTRAINT FK_MERCHANT_USERS_MERCHANT
            FOREIGN KEY (MERCHANT_ID) REFERENCES MERCHANT_EE_MERCHANTS(MERCHANT_ID)
    );

    -- Merchant roles
    CREATE TABLE MERCHANT_EE_ROLES (
        ROLE_ID VARCHAR2(50) PRIMARY KEY,
        MERCHANT_ID VARCHAR2(50) NOT NULL,
        ROLE_NAME VARCHAR2(200) NOT NULL,
        ROLE_TYPE VARCHAR2(50), -- 'SUPERADMIN', 'MAKER', 'CHECKER', 'MAKER_CHECKER'
        TASK_NAME VARCHAR2(100), -- 'reward_program_creation', 'reward_disbursement', etc.
        DESCRIPTION VARCHAR2(500),
        STATUS VARCHAR2(20) DEFAULT 'ACTIVE',
        CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT FK_MERCHANT_ROLES_MERCHANT
            FOREIGN KEY (MERCHANT_ID) REFERENCES MERCHANT_EE_MERCHANTS(MERCHANT_ID),
        CONSTRAINT UK_MERCHANT_ROLE_NAME
            UNIQUE (MERCHANT_ID, ROLE_NAME)
    );

    -- User-Role mapping
    CREATE TABLE MERCHANT_EE_USER_ROLES (
        USER_ROLE_ID VARCHAR2(50) PRIMARY KEY,
        USER_ID VARCHAR2(50) NOT NULL,
        ROLE_ID VARCHAR2(50) NOT NULL,
        ASSIGNED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ASSIGNED_BY VARCHAR2(100),
        STATUS VARCHAR2(20) DEFAULT 'ACTIVE',
        CONSTRAINT FK_USER_ROLES_USER
            FOREIGN KEY (USER_ID) REFERENCES MERCHANT_EE_USERS(USER_ID),
        CONSTRAINT FK_USER_ROLES_ROLE
            FOREIGN KEY (ROLE_ID) REFERENCES MERCHANT_EE_ROLES(ROLE_ID),
        CONSTRAINT UK_USER_ROLE_MAPPING
            UNIQUE (USER_ID, ROLE_ID)
    );

    -- Permissions/Actions
    CREATE TABLE MERCHANT_EE_PERMISSIONS (
        PERMISSION_ID VARCHAR2(50) PRIMARY KEY,
        PERMISSION_NAME VARCHAR2(200) NOT NULL,
        PERMISSION_CODE VARCHAR2(100) UNIQUE NOT NULL,
        DESCRIPTION VARCHAR2(500),
        MODULE_NAME VARCHAR2(100),
        STATUS VARCHAR2(20) DEFAULT 'ACTIVE'
    );

    -- Role-Permission mapping
    CREATE TABLE MERCHANT_EE_ROLE_PERMISSIONS (
        ROLE_PERMISSION_ID VARCHAR2(50) PRIMARY KEY,
        ROLE_ID VARCHAR2(50) NOT NULL,
        PERMISSION_ID VARCHAR2(50) NOT NULL,
        GRANTED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT FK_ROLE_PERM_ROLE
            FOREIGN KEY (ROLE_ID) REFERENCES MERCHANT_EE_ROLES(ROLE_ID),
        CONSTRAINT FK_ROLE_PERM_PERMISSION
            FOREIGN KEY (PERMISSION_ID) REFERENCES MERCHANT_EE_PERMISSIONS(PERMISSION_ID),
        CONSTRAINT UK_ROLE_PERMISSION_MAPPING
            UNIQUE (ROLE_ID, PERMISSION_ID)
    );

    -- Maker-Checker workflow requests
    CREATE TABLE MERCHANT_EE_WORKFLOW_REQUESTS (
        REQUEST_ID VARCHAR2(50) PRIMARY KEY,
        MERCHANT_ID VARCHAR2(50) NOT NULL,
        REQUEST_TYPE VARCHAR2(100) NOT NULL, -- 'ROLE_CREATION', 'USER_CREATION', etc.
        TASK_NAME VARCHAR2(100),
        REQUEST_DATA CLOB, -- JSON data for the request
        STATUS VARCHAR2(50) DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'REJECTED'
        MAKER_ID VARCHAR2(50) NOT NULL,
        CHECKER_ID VARCHAR2(50),
        MAKER_COMMENTS VARCHAR2(2000),
        CHECKER_COMMENTS VARCHAR2(2000),
        CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        REVIEWED_DATE TIMESTAMP,
        CONSTRAINT FK_WORKFLOW_MERCHANT
            FOREIGN KEY (MERCHANT_ID) REFERENCES MERCHANT_EE_MERCHANTS(MERCHANT_ID),
        CONSTRAINT FK_WORKFLOW_MAKER
            FOREIGN KEY (MAKER_ID) REFERENCES MERCHANT_EE_USERS(USER_ID),
        CONSTRAINT FK_WORKFLOW_CHECKER
            FOREIGN KEY (CHECKER_ID) REFERENCES MERCHANT_EE_USERS(USER_ID)
    );

    -- Cross-portal requests (from Admin to Merchant portal)
    CREATE TABLE MERCHANT_EE_CROSS_PORTAL_REQUESTS (
        REQUEST_ID VARCHAR2(50) PRIMARY KEY,
        ADMIN_REQUEST_ID VARCHAR2(50), -- Reference to admin portal request
        MERCHANT_ID VARCHAR2(50) NOT NULL,
        REQUEST_TYPE VARCHAR2(100) NOT NULL,
        REQUEST_STATUS VARCHAR2(50) DEFAULT 'RECEIVED',
        REQUEST_DATA CLOB,
        PROCESSED_DATE TIMESTAMP,
        CONSTRAINT FK_CROSS_PORTAL_MERCHANT
            FOREIGN KEY (MERCHANT_ID) REFERENCES MERCHANT_EE_MERCHANTS(MERCHANT_ID)
    );
    ```

    ## Java Backend Architecture

    ### 1. Entity Classes

    ```java
    // Merchant Entity
    @Entity
    @Table(name = "MERCHANT_EE_MERCHANTS")
    public class Merchant {
        @Id
        @Column(name = "MERCHANT_ID")
        private String merchantId;

        @Column(name = "MERCHANT_NAME")
        private String merchantName;

        @Enumerated(EnumType.STRING)
        private Status status;

        @CreationTimestamp
        @Column(name = "CREATED_DATE")
        private LocalDateTime createdDate;

        // Getters, setters, constructors
    }

    // MerchantUser Entity
    @Entity
    @Table(name = "MERCHANT_EE_USERS")
    public class MerchantUser {
        @Id
        @Column(name = "USER_ID")
        private String userId;

        @Column(name = "MERCHANT_ID")
        private String merchantId;

        @Column(name = "USERNAME")
        private String username;

        @Column(name = "EMAIL")
        private String email;

        @ManyToOne
        @JoinColumn(name = "MERCHANT_ID", insertable = false, updatable = false)
        private Merchant merchant;

        @ManyToMany
        @JoinTable(
            name = "MERCHANT_EE_USER_ROLES",
            joinColumns = @JoinColumn(name = "USER_ID"),
            inverseJoinColumns = @JoinColumn(name = "ROLE_ID")
        )
        private Set<MerchantRole> roles;
    }

    // MerchantRole Entity
    @Entity
    @Table(name = "MERCHANT_EE_ROLES")
    public class MerchantRole {
        @Id
        @Column(name = "ROLE_ID")
        private String roleId;

        @Column(name = "MERCHANT_ID")
        private String merchantId;

        @Column(name = "ROLE_NAME")
        private String roleName;

        @Enumerated(EnumType.STRING)
        @Column(name = "ROLE_TYPE")
        private RoleType roleType;

        @Column(name = "TASK_NAME")
        private String taskName;
    }

    // WorkflowRequest Entity
    @Entity
    @Table(name = "MERCHANT_EE_WORKFLOW_REQUESTS")
    public class WorkflowRequest {
        @Id
        @Column(name = "REQUEST_ID")
        private String requestId;

        @Column(name = "MERCHANT_ID")
        private String merchantId;

        @Column(name = "REQUEST_TYPE")
        private String requestType;

        @Column(name = "REQUEST_DATA")
        private String requestData; // JSON string

        @Enumerated(EnumType.STRING)
        private WorkflowStatus status;

        @Column(name = "MAKER_ID")
        private String makerId;

        @Column(name = "CHECKER_ID")
        private String checkerId;
    }
    ```

    ### 2. Service Layer

    ```java
    @Service
    @Transactional
    public class MerchantRoleService {

        @Autowired
        private MerchantRoleRepository merchantRoleRepository;

        @Autowired
        private WorkflowService workflowService;

        @Autowired
        private NotificationService notificationService;

        /**
         * Create super admin role for merchant (called from cross-portal request)
         */
        public void createSuperAdminRole(String merchantId, String adminRequestId) {
            try {
                // Create super admin role
                MerchantRole superAdminRole = new MerchantRole();
                superAdminRole.setRoleId(generateRoleId());
                superAdminRole.setMerchantId(merchantId);
                superAdminRole.setRoleName("superadmin_merchant_portal_for_merchant_" +
    merchantId);
                superAdminRole.setRoleType(RoleType.SUPERADMIN);
                superAdminRole.setStatus(Status.ACTIVE);
                superAdminRole.setCreatedDate(LocalDateTime.now());

                merchantRoleRepository.save(superAdminRole);

                // Update cross-portal request status
                updateCrossPortalRequestStatus(adminRequestId, "COMPLETED");

                // Send notification to admin portal
                notificationService.notifyAdminPortal(adminRequestId, "Super admin role created
    successfully");

            } catch (Exception e) {
                updateCrossPortalRequestStatus(adminRequestId, "FAILED");
                throw new ServiceException("Failed to create super admin role", e);
            }
        }

        /**
         * Submit role creation request (maker action)
         */
        public String submitRoleCreationRequest(RoleCreationRequest request, String makerId) {

            // Validate maker permissions
            validateMakerPermissions(makerId, "ROLE_CREATION", request.getMerchantId());

            // Create workflow request
            WorkflowRequest workflowRequest = new WorkflowRequest();
            workflowRequest.setRequestId(generateRequestId());
            workflowRequest.setMerchantId(request.getMerchantId());
            workflowRequest.setRequestType("ROLE_CREATION");
            workflowRequest.setTaskName(request.getTaskName());
            workflowRequest.setRequestData(convertToJson(request));
            workflowRequest.setStatus(WorkflowStatus.PENDING);
            workflowRequest.setMakerId(makerId);
            workflowRequest.setMakerComments(request.getComments());
            workflowRequest.setCreatedDate(LocalDateTime.now());

            workflowService.saveWorkflowRequest(workflowRequest);

            // Notify potential checkers
            notificationService.notifyCheckers(request.getMerchantId(), "ROLE_CREATION",
    workflowRequest.getRequestId());

            return workflowRequest.getRequestId();
        }

        /**
         * Process checker approval/rejection
         */
        public void processCheckerDecision(String requestId, String checkerId,
                                         CheckerDecision decision, String comments) {

            WorkflowRequest request = workflowService.getWorkflowRequest(requestId);

            // Validate checker permissions
            validateCheckerPermissions(checkerId, "ROLE_CREATION", request.getMerchantId());

            request.setCheckerId(checkerId);
            request.setCheckerComments(comments);
            request.setReviewedDate(LocalDateTime.now());

            if (decision == CheckerDecision.APPROVE) {
                request.setStatus(WorkflowStatus.APPROVED);

                // Execute the actual role creation
                executeRoleCreation(request);

            } else if (decision == CheckerDecision.REJECT) {
                request.setStatus(WorkflowStatus.REJECTED);

                // Notify maker about rejection
                notificationService.notifyMaker(request.getMakerId(),
                    "Role creation request rejected: " + comments);
            }

            workflowService.saveWorkflowRequest(request);
        }

        private void executeRoleCreation(WorkflowRequest request) {
            RoleCreationRequest roleRequest = parseRoleCreationRequest(request.getRequestData());

            // Create maker role
            MerchantRole makerRole = createRole(
                request.getMerchantId(),
                "maker_" + roleRequest.getTaskName() + "_merchant_portal_for_merchant_" +
    request.getMerchantId(),
                RoleType.MAKER,
                roleRequest.getTaskName()
            );

            // Create checker role
            MerchantRole checkerRole = createRole(
                request.getMerchantId(),
                "checker_" + roleRequest.getTaskName() + "_merchant_portal_for_merchant_" +
    request.getMerchantId(),
                RoleType.CHECKER,
                roleRequest.getTaskName()
            );

            // Save roles
            merchantRoleRepository.save(makerRole);
            merchantRoleRepository.save(checkerRole);

            // Create default permissions for these roles
            assignDefaultPermissions(makerRole, checkerRole, roleRequest.getTaskName());
        }
    }

    @Service
    public class CrossPortalService {

        @Autowired
        private MerchantRoleService merchantRoleService;

        /**
         * Process requests from Admin Portal
         */
        public void processCrossPortalRequest(CrossPortalRequest request) {

            switch (request.getRequestType()) {
                case "CREATE_MERCHANT_SUPERADMIN":
                    merchantRoleService.createSuperAdminRole(
                        request.getMerchantId(),
                        request.getAdminRequestId()
                    );
                    break;

                case "CREATE_MERCHANT":
                    merchantService.createMerchant(request);
                    break;

                default:
                    throw new UnsupportedOperationException("Unknown request type: " +
    request.getRequestType());
            }
        }
    }
    ```

    ### 3. Controller Layer

    ```java
    @RestController
    @RequestMapping("/api/merchant/roles")
    @PreAuthorize("hasRole('MERCHANT_USER')")
    public class MerchantRoleController {

        @Autowired
        private MerchantRoleService merchantRoleService;

        @PostMapping("/create-request")
        @PreAuthorize("hasPermission('ROLE_CREATION', 'MAKE')")
        public ResponseEntity<ApiResponse> submitRoleCreationRequest(
                @RequestBody RoleCreationRequest request,
                Authentication authentication) {

            String makerId = getCurrentUserId(authentication);
            String requestId = merchantRoleService.submitRoleCreationRequest(request, makerId);

            return ResponseEntity.ok(new ApiResponse("SUCCESS", "Role creation request
    submitted", requestId));
        }

        @PostMapping("/approve/{requestId}")
        @PreAuthorize("hasPermission('ROLE_CREATION', 'CHECK')")
        public ResponseEntity<ApiResponse> approveRoleCreation(
                @PathVariable String requestId,
                @RequestBody CheckerDecisionRequest decision,
                Authentication authentication) {

            String checkerId = getCurrentUserId(authentication);
            merchantRoleService.processCheckerDecision(requestId, checkerId,
                CheckerDecision.APPROVE, decision.getComments());

            return ResponseEntity.ok(new ApiResponse("SUCCESS", "Role creation approved"));
        }

        @PostMapping("/reject/{requestId}")
        @PreAuthorize("hasPermission('ROLE_CREATION', 'CHECK')")
        public ResponseEntity<ApiResponse> rejectRoleCreation(
                @PathVariable String requestId,
                @RequestBody CheckerDecisionRequest decision,
                Authentication authentication) {

            String checkerId = getCurrentUserId(authentication);
            merchantRoleService.processCheckerDecision(requestId, checkerId,
                CheckerDecision.REJECT, decision.getComments());

            return ResponseEntity.ok(new ApiResponse("SUCCESS", "Role creation rejected"));
        }
    }

    @RestController
    @RequestMapping("/api/cross-portal")
    public class CrossPortalController {

        @Autowired
        private CrossPortalService crossPortalService;

        @PostMapping("/process-request")
        @PreAuthorize("hasRole('SYSTEM')")
        public ResponseEntity<ApiResponse> processCrossPortalRequest(
                @RequestBody CrossPortalRequest request) {

            crossPortalService.processCrossPortalRequest(request);

            return ResponseEntity.ok(new ApiResponse("SUCCESS", "Cross-portal request
    processed"));
        }
    }
    ```

    ## Merchant Onboarding Flow

    ### Phase 1: Admin Portal Actions

    1. **Merchant Creation Request (Admin Portal)**
       ```sql
       -- Admin portal creates request to add new merchants
       INSERT INTO ADMIN_EE_WORKFLOW_REQUESTS (request_id, request_type, request_data, maker_id,
    status)
       VALUES ('REQ_001', 'CREATE_MERCHANT',
               '{"merchantId":"X","merchantName":"Merchant
    X","superAdminEmail":"admin@merchantx.com"}',
               'admin_maker_001', 'PENDING');

       INSERT INTO ADMIN_EE_WORKFLOW_REQUESTS (request_id, request_type, request_data, maker_id,
    status)
       VALUES ('REQ_002', 'CREATE_MERCHANT',
               '{"merchantId":"Y","merchantName":"Merchant
    Y","superAdminEmail":"admin@merchanty.com"}',
               'admin_maker_001', 'PENDING');
       ```

    2. **Checker Approval (Admin Portal)**
       ```sql
       -- Admin checker approves both requests
       UPDATE ADMIN_EE_WORKFLOW_REQUESTS
       SET status = 'APPROVED', checker_id = 'admin_checker_001',
           checker_comments = 'Merchant onboarding approved', reviewed_date = CURRENT_TIMESTAMP
       WHERE request_id IN ('REQ_001', 'REQ_002');
       ```

    ### Phase 2: Merchant Portal Setup

    3. **Merchant Records Creation**
       ```sql
       -- Create merchant records
       INSERT INTO MERCHANT_EE_MERCHANTS (merchant_id, merchant_name, status, created_by)
       VALUES ('X', 'Merchant X', 'ACTIVE', 'system'),
              ('Y', 'Merchant Y', 'ACTIVE', 'system');

       -- Create super admin users
       INSERT INTO MERCHANT_EE_USERS (user_id, merchant_id, username, email, first_name, status)
       VALUES ('super_admin_x', 'X', 'superadmin_x', 'admin@merchantx.com', 'Super Admin X',
    'ACTIVE'),
              ('super_admin_y', 'Y', 'superadmin_y', 'admin@merchanty.com', 'Super Admin Y',
    'ACTIVE');

       -- Create super admin roles
       INSERT INTO MERCHANT_EE_ROLES (role_id, merchant_id, role_name, role_type, status)
       VALUES ('role_super_x', 'X', 'superadmin_merchant_portal_for_merchant_X', 'SUPERADMIN',
    'ACTIVE'),
              ('role_super_y', 'Y', 'superadmin_merchant_portal_for_merchant_Y', 'SUPERADMIN',
    'ACTIVE');

       -- Assign super admin roles
       INSERT INTO MERCHANT_EE_USER_ROLES (user_role_id, user_id, role_id, assigned_by)
       VALUES ('ur_001', 'super_admin_x', 'role_super_x', 'system'),
              ('ur_002', 'super_admin_y', 'role_super_y', 'system');
       ```

    ### Phase 3: Task-Specific Role Creation

    4. **Super Admin Creates Task Roles for Merchant X**
       ```sql
       -- Super admin X submits requests for reward program roles
       INSERT INTO MERCHANT_EE_WORKFLOW_REQUESTS
       (request_id, merchant_id, request_type, task_name, request_data, maker_id, maker_comments,
     status)
       VALUES
       ('REQ_X_001', 'X', 'ROLE_CREATION', 'reward_program_creation',
        '{"taskName":"reward_program_creation","roleType":"MAKER_CHECKER","description":"Roles
    for reward program creation"}',
        'super_admin_x', 'Creating roles for reward program management', 'PENDING'),

       ('REQ_X_002', 'X', 'ROLE_CREATION', 'reward_disbursement',
        '{"taskName":"reward_disbursement","roleType":"MAKER_CHECKER","description":"Roles for
    reward disbursement"}',
        'super_admin_x', 'Creating roles for reward disbursement', 'PENDING');

       -- Auto-approval for super admin (or separate checker approval)
       UPDATE MERCHANT_EE_WORKFLOW_REQUESTS
       SET status = 'APPROVED', checker_id = 'super_admin_x',
           checker_comments = 'Auto-approved by super admin', reviewed_date = CURRENT_TIMESTAMP
       WHERE request_id IN ('REQ_X_001', 'REQ_X_002');
       ```

    5. **Create Actual Roles for Merchant X**
       ```sql
       -- Reward Program Creation roles for Merchant X
       INSERT INTO MERCHANT_EE_ROLES (role_id, merchant_id, role_name, role_type, task_name,
    status)
       VALUES
       ('role_x_rpc_maker', 'X', 'maker_reward_program_creation_merchant_portal_for_merchant_X',
    'MAKER', 'reward_program_creation', 'ACTIVE'),
       ('role_x_rpc_checker', 'X',
    'checker_reward_program_creation_merchant_portal_for_merchant_X', 'CHECKER',
    'reward_program_creation', 'ACTIVE'),

       -- Reward Disbursement roles for Merchant X
       ('role_x_rd_maker', 'X', 'maker_reward_disbursement_merchant_portal_for_merchant_X',
    'MAKER', 'reward_disbursement', 'ACTIVE'),
       ('role_x_rd_checker', 'X', 'checker_reward_disbursement_merchant_portal_for_merchant_X',
    'CHECKER', 'reward_disbursement', 'ACTIVE');
       ```

    6. **Repeat for Merchant Y**
       ```sql
       -- Similar process for Merchant Y
       INSERT INTO MERCHANT_EE_WORKFLOW_REQUESTS
       (request_id, merchant_id, request_type, task_name, request_data, maker_id, maker_comments,
     status)
       VALUES
       ('REQ_Y_001', 'Y', 'ROLE_CREATION', 'reward_program_creation',
        '{"taskName":"reward_program_creation","roleType":"MAKER_CHECKER"}',
        'super_admin_y', 'Creating roles for reward program management', 'APPROVED'),

       ('REQ_Y_002', 'Y', 'ROLE_CREATION', 'reward_disbursement',
        '{"taskName":"reward_disbursement","roleType":"MAKER_CHECKER"}',
        'super_admin_y', 'Creating roles for reward disbursement', 'APPROVED');

       -- Create roles for Merchant Y
       INSERT INTO MERCHANT_EE_ROLES (role_id, merchant_id, role_name, role_type, task_name,
    status)
       VALUES
       ('role_y_rpc_maker', 'Y', 'maker_reward_program_creation_merchant_portal_for_merchant_Y',
    'MAKER', 'reward_program_creation', 'ACTIVE'),
       ('role_y_rpc_checker', 'Y',
    'checker_reward_program_creation_merchant_portal_for_merchant_Y', 'CHECKER',
    'reward_program_creation', 'ACTIVE'),
       ('role_y_rd_maker', 'Y', 'maker_reward_disbursement_merchant_portal_for_merchant_Y',
    'MAKER', 'reward_disbursement', 'ACTIVE'),
       ('role_y_rd_checker', 'Y', 'checker_reward_disbursement_merchant_portal_for_merchant_Y',
    'CHECKER', 'reward_disbursement', 'ACTIVE');
       ```

    ## Final Role Structure

    After complete onboarding, the role structure will be:

    ### Merchant X Roles:
    - `superadmin_merchant_portal_for_merchant_X`
    - `maker_reward_program_creation_merchant_portal_for_merchant_X`
    - `checker_reward_program_creation_merchant_portal_for_merchant_X`
    - `maker_reward_disbursement_merchant_portal_for_merchant_X`
    - `checker_reward_disbursement_merchant_portal_for_merchant_X`

    ### Merchant Y Roles:
    - `superadmin_merchant_portal_for_merchant_Y`
    - `maker_reward_program_creation_merchant_portal_for_merchant_Y`
    - `checker_reward_program_creation_merchant_portal_for_merchant_Y`
    - `maker_reward_disbursement_merchant_portal_for_merchant_Y`
    - `checker_reward_disbursement_merchant_portal_for_merchant_Y`

    ## Key Implementation Notes

    1. **Tenant Isolation**: Each merchant's data is isolated using merchant_id
    2. **Workflow Engine**: All changes go through maker-checker workflow
    3. **Cross-Portal Communication**: Admin portal triggers merchant portal actions
    4. **Audit Trail**: All requests and approvals are logged with timestamps and comments
    5. **Security**: Role-based access control with granular permissions
    6. **Scalability**: Design supports adding new merchants and tasks easily
