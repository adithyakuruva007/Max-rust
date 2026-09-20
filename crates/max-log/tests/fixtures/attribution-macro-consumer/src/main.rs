use max_log_attribution_macro_support::FixtureAttributable;

fn main() {
    let _span = max_log::attribution_span!(&FixtureAttributable);
}
