// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
lazyLoadControllersFrom("controllers", application)