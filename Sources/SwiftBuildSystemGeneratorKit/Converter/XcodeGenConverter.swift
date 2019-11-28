import Path
import ProjectSpec
import Yams

public class XcodeGenConverter: ConverterInterface {
    public init() { }

    public func convert() throws {
        let xcodeGenFiles = getXcodeGenFiles()

        for xcodeGenFile in xcodeGenFiles {
            Reporter.info("converting '\(xcodeGenFile)'")

            let project = try Project(path: .init(xcodeGenFile.string))
            guard let mainTarget = project.targets.first, [.framework, .staticFramework].contains(mainTarget.type),
                let testTarget = project.targets[safe: 1], testTarget.type == .unitTestBundle else {
                continue
            }

            let dependencies = try getDependencies(for: mainTarget, using: xcodeGenFiles)
            let testDependencies = try getDependencies(for: testTarget, using: xcodeGenFiles)

            let module = Module.Yaml(
                dependencies: dependencies,
                testDependencies: testDependencies
            )

            let encoder = YAMLEncoder()
            var content = try encoder.encode(
                module,
                userInfo: [.relativePath: xcodeGenFile.parent]
            )
            if content == "{}\n" {
                // The YAMLEncoder adds brackets when there is nothing to encode. They should be removed
                content = ""
            }

            let outputPath = OutputPath.moduleFile.path(for: xcodeGenFile)
            try outputPath.delete()
            try content.write(to: outputPath)
        }
    }

    private func getXcodeGenFiles() -> [Path] {
        return cwd.find(name: XcodegenGenerator.OutputPath.projectFileName)
    }

    private func getDependencies(
        for target: ProjectSpec.Target,
        using xcodeGenFiles: [Path]
    ) throws -> [String] {
        var dependencies: [String] = []

        for dependency in target.dependencies {
            let name = getName(for: dependency)

            switch dependency.type {
            case .framework, .carthage:
                dependencies.append(name)

            case .package, .sdk, .target:
                // Nothing to do: will be handled in the templates
                continue
            }
        }

        return dependencies.sorted { $0 < $1 }
    }

    private func getName(for dependency: ProjectSpec.Dependency) -> String {
        return (cwd/dependency.reference).basename(dropExtension: true)
    }

    public func clean() throws {
        let xcodeGenFiles = getXcodeGenFiles()
        for xcodeGenFile in xcodeGenFiles {
            try OutputPath.cleanAll(for: xcodeGenFile)
        }
    }
}

extension XcodeGenConverter {
    public enum OutputPath: String, OutputPathInterface {
        case moduleFile

        public func path(for xcodeGenFilePath: Path) -> Path {
            switch self {
            case .moduleFile:
                return xcodeGenFilePath.parent/Current.options.fileName
            }
        }
    }
}
