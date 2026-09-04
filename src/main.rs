use std::process::ExitCode;

fn main() -> ExitCode {
    match ccvl::cli::run() {
        Ok(exit_code) => exit_code,
        Err(error) => {
            eprintln!("ccvl failed: {error:#}");
            ExitCode::FAILURE
        }
    }
}
