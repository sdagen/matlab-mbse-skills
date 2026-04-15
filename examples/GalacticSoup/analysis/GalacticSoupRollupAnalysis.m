function GalacticSoupRollupAnalysis(instance, varargin)
% Analysis function for the GalacticSoupPhysical.slx example

% Calculate total mass
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('GalacticSoupProfile.ComponentProperties.mass')
    total = 0;
    for child = instance.Components
        if child.hasValue('GalacticSoupProfile.ComponentProperties.mass')
           v = child.getValue('GalacticSoupProfile.ComponentProperties.mass');
           total = total + v;
        end
    end
    instance.setValue('GalacticSoupProfile.ComponentProperties.mass', total);
end

% Calculate total volume
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('GalacticSoupProfile.ComponentProperties.volume')
    total = 0;
    for child = instance.Components
        if child.hasValue('GalacticSoupProfile.ComponentProperties.volume')
           v = child.getValue('GalacticSoupProfile.ComponentProperties.volume');
           total = total + v;
        end
    end
    instance.setValue('GalacticSoupProfile.ComponentProperties.volume', total);
end

% Calculate total power
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('GalacticSoupProfile.ComponentProperties.power')
    total = 0;
    for child = instance.Components
        if child.hasValue('GalacticSoupProfile.ComponentProperties.power')
           v = child.getValue('GalacticSoupProfile.ComponentProperties.power');
           total = total + v;
        end
    end
    instance.setValue('GalacticSoupProfile.ComponentProperties.power', total);
end

% Calculate total cost
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('GalacticSoupProfile.ComponentProperties.cost')
    total = 0;
    for child = instance.Components
        if child.hasValue('GalacticSoupProfile.ComponentProperties.cost')
           v = child.getValue('GalacticSoupProfile.ComponentProperties.cost');
           total = total + v;
        end
    end
    instance.setValue('GalacticSoupProfile.ComponentProperties.cost', total);
end

% Calculate throughput bottleneck (min across producing children, excluding
% zero-throughput elements such as controllers and sensors)
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('GalacticSoupProfile.ComponentProperties.throughput')
    bottleneck = inf;
    for child = instance.Components
        if child.hasValue('GalacticSoupProfile.ComponentProperties.throughput')
           v = child.getValue('GalacticSoupProfile.ComponentProperties.throughput');
           if v > 0 && v < bottleneck
               bottleneck = v;
           end
        end
    end
    if isfinite(bottleneck)
        instance.setValue('GalacticSoupProfile.ComponentProperties.throughput', bottleneck);
    end
end

% Calculate average automation level across children
if instance.isComponent() && ~isempty(instance.Components)...
 && instance.hasValue('GalacticSoupProfile.ComponentProperties.automationLevel')
    vals = [];
    for child = instance.Components
        if child.hasValue('GalacticSoupProfile.ComponentProperties.automationLevel')
           vals(end+1) = child.getValue('GalacticSoupProfile.ComponentProperties.automationLevel'); %#ok<AGROW>
        end
    end
    if ~isempty(vals)
        instance.setValue('GalacticSoupProfile.ComponentProperties.automationLevel', mean(vals));
    end
end
