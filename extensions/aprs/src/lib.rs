use chrono::{DateTime, Utc};
use godot::prelude::*;

struct AprsExtension;

#[gdextension]
unsafe impl ExtensionLibrary for AprsExtension {}

#[derive(GodotClass)]
#[class(base=Object)]
struct Aprs {}

#[godot_api]
impl Aprs {
    #[func]
    fn parse_aprs(aprs_line: GodotString) -> Option<Gd<Object>> {
        let line = aprs_line.to_string();
        match line.parse() {
            Ok(aprs::Report::PositionReport(inner)) => {
                Some(Gd::new(AprsPositionReport { inner }).upcast())
            }
            Ok(_) => None,
            Err(e) => {
                godot_error!("Could not parse APRS message {}: {}", line, e);
                None
            }
        }
    }
}

#[derive(GodotClass)]
#[class(base=Object)]
struct AprsPositionReport {
    inner: aprs::PositionReport,
}

#[godot_api]
impl AprsPositionReport {
    /// Return the UNIX timestamp of the report, or -1 if it was not included.
    #[func]
    pub fn timestamp(&self) -> i64 {
        self.timestamp_from_time(Utc::now())
    }

    fn timestamp_from_time(&self, now: DateTime<Utc>) -> i64 {
        if let Some(t1) = &self.inner.timestamp {
            if let Ok(t) = t1.guess_datetime(now) {
                return t.timestamp();
            }
        }
        -1
    }

    #[func]
    pub fn id(&self) -> GodotString {
        self.inner
            .id()
            .map(GodotString::from)
            .unwrap_or(GodotString::new())
    }

    /// Course, between 1 and 360. 0 is invalid
    #[func]
    pub fn course(&self) -> u32 {
        self.inner.course().unwrap_or(0)
    }

    /// Speed in knots
    #[func]
    pub fn speed(&self) -> f32 {
        self.inner.speed().unwrap_or(std::f32::NAN)
    }

    /// Altitude AMSL in feet
    #[func]
    pub fn altitude(&self) -> f64 {
        self.inner.altitude().unwrap_or(std::f64::NAN)
    }

    /// Turn rate in 180deg/min, clockwise.
    #[func]
    pub fn turn_rate(&self) -> f32 {
        self.inner
            .turn_rate()
            .map(|t| t as f32)
            .unwrap_or(std::f32::NAN)
    }

    #[func]
    fn symbol(&self) -> GodotString {
        // Safety: the symbol is garanteed to be ASCII chars, as per the parser.
        GodotString::from(unsafe { std::str::from_utf8_unchecked(&self.inner.symbol) })
    }
}
