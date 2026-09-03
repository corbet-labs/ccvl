use std::process::ExitCode;

fn main() -> ExitCode {
    match ccvl::cli::run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("ccvl failed: {error:#}");
            ExitCode::FAILURE
        }
    }
}
