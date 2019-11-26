import Foundation
import Path

public class CleanAction {
    public init() throws {
        try setCurrent()
    }

    public func execute() throws {
        Reporter.print("Removing existing configuration files from path: \(Current.wd)")

        let modules = try FileIterator().start()

        Reporter.print("Found modules:")
        modules.forEach {
            let relativePath = $0.path.relative(to: Current.wd)
            Reporter.print("\(relativePath)")
        }

        let generators: [GeneratorInterface] = Current.options.generators.map {
            $0.build(modules)
        }

        for generator in generators {
            try generator.clean()
        }

        Reporter.print("Done")
    }
}
