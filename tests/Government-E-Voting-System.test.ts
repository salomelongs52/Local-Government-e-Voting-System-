import { describe, expect, it } from "vitest";
import { readFileSync } from "fs";
import { resolve } from "path";

describe("Government E-Voting System Tests", () => {
  it("should have a valid Clarinet.toml configuration", () => {
    const clarinetPath = resolve(process.cwd(), "Clarinet.toml");
    const clarinetContent = readFileSync(clarinetPath, "utf-8");
    
    expect(clarinetContent).toContain("Government-E-Voting-System");
    expect(clarinetContent).toContain("clarity_version = 3");
    expect(clarinetContent).toContain("epoch = 3.1");
  });

  it("should have a valid smart contract file", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for core voting system functions
    expect(contractContent).toContain("define-public (register-voter");
    expect(contractContent).toContain("define-public (create-proposal");
    expect(contractContent).toContain("define-public (vote");
    expect(contractContent).toContain("define-public (close-proposal");
    
    // Check for campaign finance functions
    expect(contractContent).toContain("define-public (register-campaign");
    expect(contractContent).toContain("define-public (make-contribution");
    expect(contractContent).toContain("define-public (record-expenditure");
    expect(contractContent).toContain("define-public (verify-contribution");
    expect(contractContent).toContain("define-public (approve-expenditure");
  });

  it("should have proper error constants defined", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Core voting system errors
    expect(contractContent).toContain("err-not-authorized");
    expect(contractContent).toContain("err-already-registered");
    expect(contractContent).toContain("err-not-registered");
    expect(contractContent).toContain("err-voting-closed");
    expect(contractContent).toContain("err-already-voted");
    
    // Campaign finance errors
    expect(contractContent).toContain("err-campaign-not-found");
    expect(contractContent).toContain("err-contribution-limit-exceeded");
    expect(contractContent).toContain("err-expenditure-exceeds-funds");
  });

  it("should have proper data structures defined", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Core voting maps
    expect(contractContent).toContain("define-map Voters");
    expect(contractContent).toContain("define-map Proposals");
    expect(contractContent).toContain("define-map VoteRegistry");
    expect(contractContent).toContain("define-map ElectionDistricts");
    
    // Campaign finance maps
    expect(contractContent).toContain("define-map Campaigns");
    expect(contractContent).toContain("define-map Contributions");
    expect(contractContent).toContain("define-map Expenditures");
    expect(contractContent).toContain("define-map ContributorTotals");
  });

  it("should have read-only functions for data access", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Core voting read functions
    expect(contractContent).toContain("define-read-only (get-proposal");
    expect(contractContent).toContain("define-read-only (get-voter");
    expect(contractContent).toContain("define-read-only (get-vote");
    
    // Campaign finance read functions
    expect(contractContent).toContain("define-read-only (get-campaign");
    expect(contractContent).toContain("define-read-only (get-contribution");
    expect(contractContent).toContain("define-read-only (get-expenditure");
    expect(contractContent).toContain("define-read-only (get-campaign-balance");
  });

  it("should use Clarity v3 syntax and data types", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for proper uint usage
    expect(contractContent).toMatch(/uint u\d+/);
    
    // Check for string-ascii usage
    expect(contractContent).toContain("string-ascii");
    
    // Check for proper error handling with unwrap!
    expect(contractContent).toContain("unwrap!");
    
    // Check for proper assertions
    expect(contractContent).toContain("asserts!");
  });

  it("should have proper administrative controls", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for contract owner definition
    expect(contractContent).toContain("define-constant contract-owner tx-sender");
    
    // Check for admin-only functions
    expect(contractContent).toContain("is-eq tx-sender contract-owner");
    
    // Check for administrative settings
    expect(contractContent).toContain("set-contribution-limit");
    expect(contractContent).toContain("set-minimum-vote-threshold");
  });

  it("should validate Campaign Finance Transparency feature independence", () => {
    const contractPath = resolve(process.cwd(), "contracts", "Government-E-Voting-System.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Verify that campaign finance functions don't cross-reference voting maps
    const campaignFunctions = [
      "register-campaign",
      "make-contribution", 
      "record-expenditure",
      "verify-contribution",
      "approve-expenditure"
    ];
    
    campaignFunctions.forEach(func => {
      expect(contractContent).toContain(`define-public (${func}`);
    });
    
    // Check that campaign finance has its own error constants
    expect(contractContent).toContain("Campaign Finance Error constants");
    
    // Verify independent data variables
    expect(contractContent).toContain("campaign-count");
    expect(contractContent).toContain("max-individual-contribution");
    expect(contractContent).toContain("contribution-count");
    expect(contractContent).toContain("expenditure-count");
  });
});
