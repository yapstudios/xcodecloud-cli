import Testing
import ArgumentParser
@testable import XcodeCloudCLI

/// Tests that all CLI commands parse correctly and produce expected help output
@Suite("Command Parsing Tests")
struct CommandParsingTests {

    // MARK: - Root Command

    @Test("Root command parses with no arguments")
    func testRootCommandParsesEmpty() throws {
        // When no args, should default to interactive (but we can't test that here without TTY)
        // Just verify the command structure is valid
        let command = try XcodeCloud.parseAsRoot([])
        #expect(command is InteractiveCommand)
    }

    @Test("Root command shows help")
    func testRootHelp() throws {
        let help = XcodeCloud.helpMessage()
        #expect(help.contains("Xcode Cloud"))
        #expect(help.contains("auth"))
        #expect(help.contains("products"))
        #expect(help.contains("workflows"))
        #expect(help.contains("builds"))
        #expect(help.contains("artifacts"))
        #expect(help.contains("INTERACTIVE MODE"))
        #expect(help.contains("AUTHENTICATION"))
    }

    // MARK: - Auth Commands

    @Test("Auth command shows help")
    func testAuthHelp() throws {
        let help = AuthCommand.helpMessage()
        #expect(help.contains("Manage authentication"))
        #expect(help.contains("init"))
        #expect(help.contains("check"))
        #expect(help.contains("profiles"))
        #expect(help.contains("use"))
        #expect(help.contains("Team key"))
    }

    @Test("Auth init parses with default profile")
    func testAuthInitDefault() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "init"])
        #expect(command is AuthInitCommand)
        let initCmd = command as! AuthInitCommand
        #expect(initCmd.profile == "default")
        #expect(initCmd.force == false)
    }

    @Test("Auth init parses with custom profile")
    func testAuthInitCustomProfile() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "init", "--profile", "work"])
        let initCmd = command as! AuthInitCommand
        #expect(initCmd.profile == "work")
    }

    @Test("Auth init parses with force flag")
    func testAuthInitForce() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "init", "--force"])
        let initCmd = command as! AuthInitCommand
        #expect(initCmd.force == true)
    }

    @Test("Auth check parses")
    func testAuthCheck() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "check"])
        #expect(command is AuthCheckCommand)
    }

    @Test("Auth profiles parses")
    func testAuthProfiles() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "profiles"])
        #expect(command is AuthProfilesCommand)
    }

    @Test("Auth use parses with profile name")
    func testAuthUse() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "use", "work"])
        #expect(command is AuthUseCommand)
        let useCmd = command as! AuthUseCommand
        #expect(useCmd.profile == "work")
    }

    @Test("Auth use with local flag")
    func testAuthUseLocal() throws {
        let command = try XcodeCloud.parseAsRoot(["auth", "use", "work", "--local"])
        let useCmd = command as! AuthUseCommand
        #expect(useCmd.local == true)
    }

    // MARK: - Products Commands

    @Test("Products command shows help")
    func testProductsHelp() throws {
        let help = ProductsCommand.helpMessage()
        #expect(help.contains("CI products"))
        #expect(help.contains("list"))
        #expect(help.contains("get"))
    }

    @Test("Products list parses")
    func testProductsList() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list"])
        #expect(command is ProductsListCommand)
    }

    @Test("Products list with limit")
    func testProductsListWithLimit() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "--limit", "50"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.limit == 50)
    }

    @Test("Products list with output format")
    func testProductsListWithFormat() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "-o", "table"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.output == .table)
    }

    @Test("Products get parses with ID")
    func testProductsGet() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "get", "abc123"])
        #expect(command is ProductsGetCommand)
        let getCmd = command as! ProductsGetCommand
        #expect(getCmd.id == "abc123")
    }

    // MARK: - Workflows Commands

    @Test("Workflows command shows help")
    func testWorkflowsHelp() throws {
        let help = WorkflowsCommand.helpMessage()
        #expect(help.contains("workflows"))
        #expect(help.contains("list"))
        #expect(help.contains("get"))
    }

    @Test("Workflows list parses with product ID")
    func testWorkflowsList() throws {
        let command = try XcodeCloud.parseAsRoot(["workflows", "list", "product123"])
        #expect(command is WorkflowsListCommand)
        let listCmd = command as! WorkflowsListCommand
        #expect(listCmd.productId == "product123")
    }

    @Test("Workflows get parses with ID")
    func testWorkflowsGet() throws {
        let command = try XcodeCloud.parseAsRoot(["workflows", "get", "workflow123"])
        #expect(command is WorkflowsGetCommand)
        let getCmd = command as! WorkflowsGetCommand
        #expect(getCmd.id == "workflow123")
    }

    // MARK: - Builds Commands

    @Test("Builds command shows help")
    func testBuildsHelp() throws {
        let help = BuildsCommand.helpMessage()
        #expect(help.contains("build runs"))
        #expect(help.contains("list"))
        #expect(help.contains("get"))
        #expect(help.contains("start"))
        #expect(help.contains("actions"))
        #expect(help.contains("errors"))
        #expect(help.contains("tests"))
    }

    @Test("Builds list parses")
    func testBuildsList() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "list"])
        #expect(command is BuildsListCommand)
    }

    @Test("Builds list with workflow filter")
    func testBuildsListWithWorkflow() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "list", "--workflow", "wf123"])
        let listCmd = command as! BuildsListCommand
        #expect(listCmd.workflow == "wf123")
    }

    @Test("Builds get parses with ID")
    func testBuildsGet() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "get", "build123"])
        #expect(command is BuildsGetCommand)
        let getCmd = command as! BuildsGetCommand
        #expect(getCmd.id == "build123")
    }

    @Test("Builds start parses with workflow ID")
    func testBuildsStart() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "start", "workflow123"])
        #expect(command is BuildsStartCommand)
        let startCmd = command as! BuildsStartCommand
        #expect(startCmd.workflowId == "workflow123")
    }

    @Test("Builds start with branch")
    func testBuildsStartWithBranch() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "start", "wf123", "--branch", "main"])
        let startCmd = command as! BuildsStartCommand
        #expect(startCmd.branch == "main")
        #expect(startCmd.tag == nil)
    }

    @Test("Builds start with tag")
    func testBuildsStartWithTag() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "start", "wf123", "--tag", "v1.0.0"])
        let startCmd = command as! BuildsStartCommand
        #expect(startCmd.tag == "v1.0.0")
        #expect(startCmd.branch == nil)
    }

    @Test("Builds watch parses with build ID")
    func testBuildsWatch() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "watch", "build123"])
        #expect(command is BuildsWatchCommand)
        let watchCmd = command as! BuildsWatchCommand
        #expect(watchCmd.id == "build123")
        #expect(watchCmd.interval == 10)
    }

    @Test("Builds watch parses with custom interval")
    func testBuildsWatchWithInterval() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "watch", "build123", "--interval", "5"])
        let watchCmd = command as! BuildsWatchCommand
        #expect(watchCmd.interval == 5)
    }

    @Test("Builds actions parses with build ID")
    func testBuildsActions() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "actions", "build123"])
        #expect(command is BuildsActionsCommand)
        let actionsCmd = command as! BuildsActionsCommand
        #expect(actionsCmd.buildId == "build123")
    }

    @Test("Builds errors parses with build ID")
    func testBuildsErrors() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "errors", "build123"])
        #expect(command is BuildsErrorsCommand)
        let errorsCmd = command as! BuildsErrorsCommand
        #expect(errorsCmd.buildId == "build123")
    }

    @Test("Builds issues parses with action ID")
    func testBuildsIssues() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "issues", "action123"])
        #expect(command is BuildsIssuesCommand)
        let issuesCmd = command as! BuildsIssuesCommand
        #expect(issuesCmd.actionId == "action123")
    }

    @Test("Builds tests parses with build ID")
    func testBuildsTests() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "tests", "build123"])
        #expect(command is BuildsTestsCommand)
        let testsCmd = command as! BuildsTestsCommand
        #expect(testsCmd.buildId == "build123")
        #expect(testsCmd.failures == false)
    }

    @Test("Builds tests with failures flag")
    func testBuildsTestsFailuresOnly() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "tests", "build123", "--failures"])
        let testsCmd = command as! BuildsTestsCommand
        #expect(testsCmd.failures == true)
    }

    @Test("Builds issue parses with issue ID")
    func testBuildsIssue() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "issue", "issue123"])
        #expect(command is BuildsIssueGetCommand)
        let issueCmd = command as! BuildsIssueGetCommand
        #expect(issueCmd.id == "issue123")
    }

    @Test("Builds test-result parses with test result ID")
    func testBuildsTestResult() throws {
        let command = try XcodeCloud.parseAsRoot(["builds", "test-result", "testresult123"])
        #expect(command is BuildsTestResultGetCommand)
        let resultCmd = command as! BuildsTestResultGetCommand
        #expect(resultCmd.id == "testresult123")
    }

    // MARK: - Artifacts Commands

    @Test("Artifacts command shows help")
    func testArtifactsHelp() throws {
        let help = ArtifactsCommand.helpMessage()
        #expect(help.contains("artifacts"))
        #expect(help.contains("list"))
        #expect(help.contains("download"))
        #expect(help.contains("WORKFLOW"))
    }

    @Test("Artifacts list parses with action ID")
    func testArtifactsList() throws {
        let command = try XcodeCloud.parseAsRoot(["artifacts", "list", "action123"])
        #expect(command is ArtifactsListCommand)
        let listCmd = command as! ArtifactsListCommand
        #expect(listCmd.buildActionId == "action123")
    }

    @Test("Artifacts download parses with artifact ID")
    func testArtifactsDownload() throws {
        let command = try XcodeCloud.parseAsRoot(["artifacts", "download", "artifact123"])
        #expect(command is ArtifactsDownloadCommand)
        let downloadCmd = command as! ArtifactsDownloadCommand
        #expect(downloadCmd.artifactId == "artifact123")
        #expect(downloadCmd.outputDir == ".")
    }

    @Test("Artifacts download with custom directory")
    func testArtifactsDownloadWithDir() throws {
        let command = try XcodeCloud.parseAsRoot(["artifacts", "download", "artifact123", "--dir", "~/Downloads"])
        let downloadCmd = command as! ArtifactsDownloadCommand
        #expect(downloadCmd.outputDir == "~/Downloads")
    }

    // MARK: - Global Options

    @Test("Verbose flag parses")
    func testVerboseFlag() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "--verbose"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.verbose == true)
    }

    @Test("Quiet flag parses")
    func testQuietFlag() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "--quiet"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.quiet == true)
    }

    @Test("Pretty flag parses")
    func testPrettyFlag() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "--pretty"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.pretty == true)
    }

    @Test("Profile option parses")
    func testProfileOption() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "--profile", "work"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.profile == "work")
    }

    @Test("Output format table parses")
    func testOutputFormatTable() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "-o", "table"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.output == .table)
    }

    @Test("Output format csv parses")
    func testOutputFormatCSV() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "-o", "csv"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.output == .csv)
    }

    @Test("Output format json parses")
    func testOutputFormatJSON() throws {
        let command = try XcodeCloud.parseAsRoot(["products", "list", "-o", "json"])
        let listCmd = command as! ProductsListCommand
        #expect(listCmd.options.output == .json)
    }

    // MARK: - Error Cases

    @Test("Missing required argument throws")
    func testMissingArgument() {
        #expect(throws: Error.self) {
            _ = try XcodeCloud.parseAsRoot(["products", "get"])
        }
    }

    @Test("Invalid subcommand throws")
    func testInvalidSubcommand() {
        #expect(throws: Error.self) {
            _ = try XcodeCloud.parseAsRoot(["invalid"])
        }
    }

    @Test("Invalid output format throws")
    func testInvalidOutputFormat() {
        #expect(throws: Error.self) {
            _ = try XcodeCloud.parseAsRoot(["products", "list", "-o", "invalid"])
        }
    }
}
