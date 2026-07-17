//
//  Logi_Options_Plus_mini_test.swift
//  Logi-Options-Plus-mini-test
//
//  Created by Qetesh Wong on 2025/8/11.
//

import Testing
import Foundation
@testable import Logi_Options__mini

struct Logi_Options_Plus_mini_test {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testLogiOptionsPlusLatestVersionFetch() async throws {
        // 测试能否成功获取最新版本
        let version = await getLogiOptionsPlusLatestVersion()
        
        // 验证返回的版本不是"Unknown"，表示成功获取
        #expect(version != "Unknown", "应该成功获取最新版本")
        #expect(!version.isEmpty, "版本号不应为空")
        
        print("获取到的最新版本: \(version)")
    }
    
    @Test func testAppVersionDetection() async throws {
        // 测试应用版本检测功能（无需实际安装应用）
        let version = getLogiOptionsPlusVersion()
        
        // 验证函数能正确处理未安装的情况
        #expect(version == "not installed" || !version.isEmpty, "应该返回 'not installed' 或有效版本号")
        
        print("当前检测到的版本: \(version)")
    }
    
    @Test func testAppVersionUsingBundle() async throws {
        // 测试Bundle版本读取功能
        let testPath = "/Applications/logioptionsplus.app"
        let version = getAppVersionUsingBundle(appPath: testPath)
        
        // 验证函数返回正确类型（可能为nil如果应用未安装）
        if let version = version {
            #expect(!version.isEmpty, "如果找到版本，版本号不应为空")
            print("Bundle中检测到的版本: \(version)")
        } else {
            print("应用未安装，无法获取版本")
        }
    }

}
